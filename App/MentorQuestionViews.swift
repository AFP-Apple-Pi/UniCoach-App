import SwiftUI
import UniCoachCore

struct MentorLanding: View {
  @Environment(AppState.self) private var app
  @State private var chosen: Assignment?
  @State private var session: MentorSession?
  @State private var deleting: SavedMentorConversation?

  private var conversations: [SavedMentorConversation] {
    let answers = app.data.mentorAnswers
    var firstByThread = Dictionary(
      answers.map { ($0.threadID, $0) }, uniquingKeysWith: { _, earlier in earlier })
    return answers.compactMap { latest in
      guard let first = firstByThread.removeValue(forKey: latest.threadID) else { return nil }
      return SavedMentorConversation(
        id: latest.threadID, question: first.question, updatedAt: latest.createdAt)
    }
  }

  var body: some View {
    List {
      Section {
        Text("Ask your mentor a question, continue a saved conversation, or review assignment feedback.")
          .foregroundStyle(.secondary)
        Button("New conversation") { session = .new }
          .accessibilityIdentifier("mentor.ask")
      }
      Section("Saved conversations") {
        if conversations.isEmpty {
          Text("Your saved conversations will appear here.").foregroundStyle(.secondary)
        }
        ForEach(conversations) { conversation in
          Button {
            session = .saved(conversation.id)
          } label: {
            LabeledContent {
              Text(conversation.updatedAt, format: .dateTime.month().day())
                .font(.caption)
            } label: {
              Text(conversation.question).lineLimit(2)
            }
          }
          .accessibilityIdentifier("mentor.conversation")
          .swipeActions(allowsFullSwipe: false) {
            Button("Delete", role: .destructive) { deleting = conversation }
          }
        }
      }
      Section("Review assignment feedback") {
        if app.data.assignments.isEmpty {
          Text("Add an assignment in My Learning to review feedback.").foregroundStyle(.secondary)
        }
        ForEach(app.data.assignments) { assignment in
          Button {
            chosen = assignment
          } label: {
            VStack(alignment: .leading) {
              Text(assignment.title).font(.headline)
              if let subject = app.data.subjects.first(where: { $0.id == assignment.subjectID }) {
                Text(subject.name).font(.caption).foregroundStyle(.secondary)
              }
            }
          }
        }
      }
    }
    .confirmationDialog("Delete this conversation?", isPresented: Binding(
      get: { deleting != nil }, set: { if !$0 { deleting = nil } }
    ), titleVisibility: .visible) {
      Button("Delete conversation", role: .destructive) {
        if let deleting { app.perform { try app.store.deleteMentorConversation(id: deleting.id) } }
        deleting = nil
      }
    } message: { Text("This removes all messages and request snapshots in this conversation.") }
    .navigationTitle("AI Mentor")
    .sheet(item: $chosen) { MentorView(assignmentID: $0.id) }
    .sheet(item: $session) { MentorSessionView(conversationID: $0.conversationID) }
  }
}

private struct SavedMentorConversation: Identifiable {
  let id: UUID
  let question: String
  let updatedAt: Date
}

private enum MentorSession: Hashable, Identifiable {
  case new
  case saved(UUID)

  var id: Self { self }
  var conversationID: UUID? {
    if case .saved(let id) = self { return id }
    return nil
  }
}

private struct MentorSessionView: View {
  @Environment(AppState.self) private var app
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @State private var conversationID: UUID?
  @State private var draft = ConsentDraft(purpose: .mentorQuestion)
  @State private var request = MentorQuestionRequest()
  @State private var activeSheet: ChatSheet?
  @State private var availabilityRevision = 0

  private enum ChatSheet: String, Identifiable {
    case sources, requestDetails
    var id: Self { self }
  }

  init(conversationID: UUID?) {
    _conversationID = State(initialValue: conversationID)
  }

  var body: some View {
    let history = conversationID.flatMap { try? app.store.conversationSnapshot(id: $0) }
    let answers = conversationID.map { app.store.conversationAnswers(id: $0) } ?? []
    let characterCount = draft.question.count + (history?.transcript.count ?? 0)
      + draft.selectedSources.reduce(0) { $0 + $1.text.count }
    let limit = UniCoachStore.contextCharacterLimit
    let limitExceeded = characterCount > limit || (history?.transcript.count ?? 0) >= limit
    let conversationUnavailable = conversationID != nil && history == nil
    NavigationStack {
      MentorChatTranscript(
        answers: answers, history: history, conversationUnavailable: conversationUnavailable,
        pendingQuestion: request.running ? draft.question : nil,
        progress: request.processingProgress,
        animateWelcomeMascot: activeSheet == nil && request.message == nil,
        onStarter: { draft.question = $0 })
      .safeAreaInset(edge: .bottom, spacing: 0) {
        MentorChatComposer(
          message: $draft.question, sourceCount: draft.selectedSources.count, hasHistory: history != nil,
          limitExceeded: limitExceeded, conversationUnavailable: conversationUnavailable,
          running: request.running, availabilityMessage: modelAvailable() ? nil : modelAvailability(),
          availabilityRevision: availabilityRevision,
          onSources: { activeSheet = .sources },
          onReview: { activeSheet = .requestDetails },
          onApprove: { send(approving: history) },
          onCancel: { request.cancel(in: app.store) })
      }
      .background(canvasColor)
      .navigationTitle("Conversation")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            request.cancel(in: app.store)
            dismiss()
          }
        }
        ToolbarItem(placement: .primaryAction) {
          Button("New conversation", systemImage: "square.and.pencil") {
            conversationID = nil
            draft = ConsentDraft(purpose: .mentorQuestion)
          }
          .labelStyle(.iconOnly)
          .accessibilityIdentifier("conversation.new")
          .disabled(request.running)
        }
      }
      .navigationDestination(for: UUID.self) { id in
        if let answer = app.data.mentorAnswers.first(where: { $0.id == id }) {
          MentorAnswerDetail(answer: answer)
        } else {
          ContentUnavailableView("Request unavailable", systemImage: "bubble.left")
        }
      }
    }
    .sheet(item: $activeSheet) { sheet in
      switch sheet {
      case .sources:
        MentorContextSheet(draft: draft) { reviewed in draft = reviewed }
      case .requestDetails:
        MentorRequestDetailsSheet(draft: draft, history: history)
      }
    }
    .interactiveDismissDisabled(request.running)
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { availabilityRevision += 1 }
    }
    .onDisappear { request.cancel(in: app.store) }
    .alert("Mentor", isPresented: Binding(
      get: { request.message != nil }, set: { if !$0 { request.message = nil } }
    )) {
      Button("OK") { request.message = nil }
    } message: { Text(request.message ?? "") }
  }

  private func send(approving history: MentorConversationSnapshot?) {
    guard !request.running, modelAvailable(), conversationID == nil || history != nil else { return }
    var approvedDraft = draft
    approvedDraft.engine = .appleOnDevice
    approvedDraft.conversation = history
    // The message can be retried, but private sources need fresh selection after every attempt.
    draft = ConsentDraft(question: draft.question, purpose: .mentorQuestion)
    request.start(draft: approvedDraft, in: app.store) { answer in
      conversationID = answer.threadID
      draft = ConsentDraft(purpose: .mentorQuestion)
    }
  }
}

private struct MentorChatTranscript: View {
  let answers: [MentorAnswer]
  let history: MentorConversationSnapshot?
  let conversationUnavailable: Bool
  let pendingQuestion: String?
  let progress: String?
  let animateWelcomeMascot: Bool
  let onStarter: (String) -> Void
  @State private var scrollTarget: ScrollTarget?

  private enum ScrollTarget: Hashable {
    case turn(UUID)
    case pending
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 16) {
        if conversationUnavailable {
          ContentUnavailableView("Conversation unavailable", systemImage: "bubble.left")
        } else if answers.isEmpty && pendingQuestion == nil {
          MentorChatWelcome(animateMascot: animateWelcomeMascot, onStarter: onStarter)
        }
        ForEach(Array(answers.enumerated()), id: \.element.id) { index, answer in
          MentorConversationTurnView(answer: answer, index: index)
            .disabled(pendingQuestion != nil)
            .id(ScrollTarget.turn(answer.id))
        }
        if let pendingQuestion {
          VStack(spacing: 12) {
            MentorUserBubble(question: pendingQuestion, identifier: "conversation.pending")
            HStack(alignment: .top, spacing: 10) {
              MentorMascotView(placement: .avatar)
              ProgressView(progress ?? "Preparing your request…")
                .font(.subheadline)
                .padding(12)
                .background(.background, in: .rect(cornerRadius: 18))
              Spacer(minLength: 24)
            }
          }
          .id(ScrollTarget.pending)
        }
        if let history {
          DisclosureGroup("Review exact conversation history") {
            MentorScrollableSnapshot(text: history.transcript, identifier: "conversation.history")
          }
          .font(.footnote)
        }
      }
      .scrollTargetLayout()
      .padding()
      .frame(maxWidth: 760)
      .frame(maxWidth: .infinity)
    }
    .scrollPosition(id: $scrollTarget, anchor: .top)
    .scrollDismissesKeyboard(.interactively)
    .accessibilityIdentifier("conversation.transcript")
    .onChange(of: answers.last?.id, initial: true) { _, id in
      scrollTarget = id.map(ScrollTarget.turn)
    }
    .onChange(of: pendingQuestion != nil) { _, pending in
      if pending { scrollTarget = .pending }
    }
  }
}

private struct MentorChatWelcome: View {
  let animateMascot: Bool
  let onStarter: (String) -> Void
  private let starters = ["How can I plan my study time?", "How can I improve my next assignment?"]

  var body: some View {
    VStack(spacing: 12) {
      MentorMascotView(placement: .welcome, allowsMotion: animateMascot)
      Text("How can I help you learn?")
        .font(.custom("Inter-Regular", size: 24, relativeTo: .title2).weight(.semibold))
        .foregroundStyle(teal)
        .accessibilityAddTraits(.isHeader)
      Text("Ask a study question, work through feedback, or plan your next step.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      ForEach(Array(starters.enumerated()), id: \.offset) { index, starter in
        Button(starter) { onStarter(starter) }
          .buttonStyle(.bordered)
          .accessibilityIdentifier(index == 0 ? "question.starter" : "question.starter.assignment")
      }
    }
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
    .padding(20)
    .background(lavender, in: .rect(cornerRadius: 24))
  }
}

private struct MentorMascotView: View {
  enum Placement { case welcome, avatar }

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 36
  @State private var visible = false

  let placement: Placement
  var allowsMotion = false

  var body: some View {
    let image = Image("MentorMascot")
      .resizable()
      .scaledToFit()
      .frame(
        width: placement == .avatar ? avatarSize : nil,
        height: placement == .avatar ? avatarSize : 108)
      .accessibilityHidden(true)
    let welcome = ZStack {
      if allowsMotion && visible && scenePhase == .active && !reduceMotion {
        image.phaseAnimator([false, true]) { mascot, lifted in
          mascot
            .rotationEffect(.degrees(lifted ? 2 : 0), anchor: .bottom)
            .offset(y: lifted ? -4 : 0)
        } animation: { _ in .easeInOut(duration: 2) }
      } else {
        image
      }
    }

    if placement == .avatar {
      image.background(lavender, in: .circle)
    } else if #available(iOS 18.0, *) {
      welcome.onScrollVisibilityChange(threshold: 0.5) { visible = $0 }
    } else {
      welcome
        .onAppear { visible = true }
        .onDisappear { visible = false }
    }
  }
}

private struct MentorUserBubble: View {
  let question: String
  let identifier: String

  var body: some View {
    HStack {
      Spacer(minLength: 40)
      VStack(alignment: .leading, spacing: 4) {
        Text("You").font(.caption).foregroundStyle(.secondary)
        MentorSnapshotText(title: "Show full question", text: question, identifier: identifier)
      }
      .padding(12)
      .background(lavender, in: .rect(cornerRadius: 18))
    }
  }
}

private struct MentorConversationTurnView: View {
  let answer: MentorAnswer
  let index: Int

  var body: some View {
    VStack(spacing: 12) {
      MentorUserBubble(question: answer.question, identifier: "conversation.question.\(index)")
      HStack(alignment: .top, spacing: 10) {
        MentorMascotView(placement: .avatar)
        VStack(alignment: .leading, spacing: 6) {
          Text("Mentor").font(.caption).foregroundStyle(.secondary)
          Text(answer.answer)
            .textSelection(.enabled)
            .accessibilityIdentifier("conversation.answer.\(index)")
          NavigationLink("Request details", value: answer.id)
            .font(.footnote)
            .accessibilityIdentifier("conversation.request.\(index)")
        }
        .padding(12)
        .background(.background, in: .rect(cornerRadius: 18))
        Spacer(minLength: 24)
      }
    }
  }
}

private struct MentorChatComposer: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Binding var message: String
  @FocusState private var focused: Bool
  let sourceCount: Int
  let hasHistory: Bool
  let limitExceeded: Bool
  let conversationUnavailable: Bool
  let running: Bool
  let availabilityMessage: String?
  let availabilityRevision: Int
  let onSources: () -> Void
  let onReview: () -> Void
  let onApprove: () -> Void
  let onCancel: () -> Void

  private var sourceLabel: String {
    if sourceCount == 0 { return "Add context" }
    if sourceCount == 1 { return "1 source selected" }
    return "\(sourceCount) sources selected"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      TextField("Message your mentor", text: $message, axis: .vertical)
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 1...2 : 1...4)
        .focused($focused)
        .disabled(running || conversationUnavailable)
        .padding(12)
        .background(.background, in: .rect(cornerRadius: 16))
        .accessibilityIdentifier("conversation.input")
      if dynamicTypeSize.isAccessibilitySize {
        MentorCompactComposerActions(
          sourceLabel: sourceLabel, sourceCount: sourceCount, hasHistory: hasHistory,
          conversationUnavailable: conversationUnavailable, running: running,
          approveDisabled: approveDisabled, onSources: openSources, onReview: openReview,
          onApprove: approve, onCancel: onCancel)
      } else {
        ViewThatFits(in: .horizontal) {
          HStack { MentorComposerActions(
            sourceLabel: sourceLabel, disabled: conversationUnavailable, running: running,
            approveDisabled: approveDisabled, onSources: openSources, onApprove: approve, onCancel: onCancel) }
          VStack(alignment: .leading) { MentorComposerActions(
            sourceLabel: sourceLabel, disabled: conversationUnavailable, running: running,
            approveDisabled: approveDisabled, onSources: openSources, onApprove: approve, onCancel: onCancel) }
        }
        Text(mentorRequestDisclosure(hasHistory: hasHistory))
          .font(.caption)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("conversation.disclosure")
        Text("Large requests may use summaries that omit details.")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      if limitExceeded {
        Text("Keep this request within \(UniCoachStore.contextCharacterLimit.formatted()) characters. Shorten the message or context, or start a new conversation.")
          .font(.caption)
          .accessibilityIdentifier("conversation.limit")
      }
      if let availabilityMessage {
        Text(availabilityMessage)
          .font(.caption)
          .id(availabilityRevision)
          .accessibilityIdentifier("conversation.availability")
      }
    }
    .padding(12)
    .frame(maxWidth: 760)
    .frame(maxWidth: .infinity)
    .background(.regularMaterial)
    .overlay(alignment: .top) { Divider() }
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { focused = false }.accessibilityIdentifier("conversation.keyboardDone")
      }
    }
  }

  private var approveDisabled: Bool {
    conversationUnavailable || limitExceeded || availabilityMessage != nil
      || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private func openSources() {
    focused = false
    onSources()
  }

  private func openReview() {
    focused = false
    onReview()
  }

  private func approve() {
    focused = false
    onApprove()
  }
}

private struct MentorComposerActions: View {
  let sourceLabel: String
  let disabled: Bool
  let running: Bool
  let approveDisabled: Bool
  let onSources: () -> Void
  let onApprove: () -> Void
  let onCancel: () -> Void

  var body: some View {
    Button(sourceLabel, systemImage: "paperclip", action: onSources)
      .buttonStyle(.bordered)
      .accessibilityIdentifier("conversation.sources")
      .disabled(disabled || running)
    if running {
      Button("Cancel request", systemImage: "stop.fill", action: onCancel)
        .buttonStyle(.bordered)
        .accessibilityIdentifier("conversation.cancel")
    } else {
      Button("Approve & send", systemImage: "arrow.up", action: onApprove)
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Approve and send to Apple on-device AI")
        .accessibilityIdentifier("conversation.send")
        .disabled(approveDisabled)
    }
  }
}

private struct MentorCompactComposerActions: View {
  @Environment(\.colorScheme) private var colorScheme
  let sourceLabel: String
  let sourceCount: Int
  let hasHistory: Bool
  let conversationUnavailable: Bool
  let running: Bool
  let approveDisabled: Bool
  let onSources: () -> Void
  let onReview: () -> Void
  let onApprove: () -> Void
  let onCancel: () -> Void

  private var scope: String {
    var parts = ["message"]
    if hasHistory { parts.append("chat") }
    if sourceCount > 0 {
      parts.append(sourceCount == 1 ? "1 source" : "\(sourceCount) sources")
    }
    return "Apple on-device AI · " + parts.joined(separator: ", ")
  }

  var body: some View {
    HStack(spacing: 8) {
      MentorCompactIconButton(label: sourceLabel, symbol: "paperclip", action: onSources)
        .accessibilityIdentifier("conversation.sources")
        .disabled(conversationUnavailable || running)
      MentorCompactIconButton(label: "Review request", symbol: "info.circle", action: onReview)
        .accessibilityIdentifier("conversation.reviewRequest")
        .disabled(running)
      Spacer(minLength: 0)
      if running {
        Button("Cancel", systemImage: "stop.fill", action: onCancel)
          .buttonStyle(.bordered)
          .accessibilityLabel("Cancel request")
          .accessibilityIdentifier("conversation.cancel")
      } else {
        Button(action: onApprove) {
          Text("Approve")
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(colorScheme == .dark ? Color(red: 0.09, green: 0.24, blue: 0.20) : .white)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Approve and send to Apple on-device AI")
        .accessibilityIdentifier("conversation.send")
        .disabled(approveDisabled)
        .layoutPriority(1)
      }
    }
    Text(scope)
      .font(.caption2)
      .foregroundStyle(.secondary)
      .accessibilityIdentifier("conversation.disclosure")
  }
}

private struct MentorCompactIconButton: View {
  let label: String
  let symbol: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 20))
        .frame(width: 44, height: 44)
        .background(lavender, in: .circle)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}

private struct MentorRequestDetailsSheet: View {
  @Environment(\.dismiss) private var dismiss
  let draft: ConsentDraft
  let history: MentorConversationSnapshot?

  var body: some View {
    NavigationStack {
      List {
        Section("How this request is processed") {
          Text(mentorRequestDisclosure(hasHistory: history != nil))
          MentorLargeContextNotice()
        }
        Section("Message") {
          MentorSnapshotText(
            title: "Show full message", text: draft.question.isEmpty ? "No message entered." : draft.question,
            identifier: "conversation.review.message")
        }
        Section("Conversation history") {
          if let history {
            MentorSnapshotText(
              title: "Show exact history", text: history.transcript,
              identifier: "conversation.review.history")
          } else {
            Text("No prior messages.")
          }
        }
        Section("Selected source text") {
          if draft.selectedSources.isEmpty { Text("No private context selected.") }
          ForEach(draft.selectedSources) { source in
            VStack(alignment: .leading, spacing: 8) {
              Text(source.title).font(.headline)
              MentorSnapshotText(
                title: "Show approved text", text: source.text,
                identifier: "conversation.review.source." + source.id)
            }
          }
        }
      }
      .navigationTitle("Review request")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
      }
    }
  }
}

private func mentorRequestDisclosure(hasHistory: Bool) -> String {
  if hasHistory {
    return "Apple on-device AI uses this message, the conversation above and any selected text. Earlier private source snapshots are excluded. Visible messages may repeat details from them."
  }
  return "Apple on-device AI uses this message and any selected text."
}

private struct MentorContextSheet: View {
  @Environment(AppState.self) private var app
  @Environment(\.dismiss) private var dismiss
  @ScaledMetric(relativeTo: .body) private var approvedTextHeight: CGFloat = 140
  @State private var draft: ConsentDraft
  @FocusState private var editingSource: String?
  let onUse: (ConsentDraft) -> Void

  init(draft: ConsentDraft, onUse: @escaping (ConsentDraft) -> Void) {
    _draft = State(initialValue: draft)
    self.onUse = onUse
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Choose private context") {
          Text("Select only the text you want Apple on-device AI to use for this request.")
            .font(.caption).foregroundStyle(.secondary)
          ForEach(app.store.contextSources()) { source in
            let title = sourceTitle(source)
            Toggle(title, isOn: Binding(
              get: { draft.selectedSources.contains { $0.id == source.id } },
              set: { selected in
                var reviewedSource = source
                reviewedSource.title = title
                draft.setSelected(selected, source: reviewedSource)
              }
            ))
            .accessibilityIdentifier("question.source." + source.id)
          }
        }
        Section("Review selected text") {
          if draft.selectedSources.isEmpty {
            Text("No private context selected.").foregroundStyle(.secondary)
          }
          ForEach(draft.selectedSources) { source in
            VStack(alignment: .leading) {
              Text(source.title).font(.headline)
              TextEditor(text: Binding(
                get: { draft.selectedSources.first { $0.id == source.id }?.text ?? "" },
                set: { draft.setText($0, sourceID: source.id) }
              ))
              .focused($editingSource, equals: source.id)
              .accessibilityLabel("Approved text for " + source.title)
              .frame(height: approvedTextHeight)
            }
          }
        }
      }
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle("Add context")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Use selected text") {
            onUse(draft)
            dismiss()
          }
          .accessibilityIdentifier("conversation.useSources")
          .disabled(draft.selectedSources.contains { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { editingSource = nil }.accessibilityIdentifier("question.keyboardDone")
        }
      }
    }
  }

  private func sourceTitle(_ source: ContextSource) -> String {
    if let assignment = app.data.assignments.first(where: { source.id.contains($0.id.uuidString) }) {
      let subject = app.data.subjects.first { $0.id == assignment.subjectID }?.name
      return [subject, assignment.title, source.title].compactMap { $0 }.joined(separator: ": ")
    }
    if let subject = app.data.subjects.first(where: { source.id == "subject:\($0.id.uuidString)" }) {
      return "\(subject.name): \(source.title)"
    }
    if let goal = app.data.goals.first(where: { source.id == "goal:\($0.id.uuidString)" }) {
      return "\(goal.title): \(source.title)"
    }
    return source.title
  }
}

@MainActor @Observable
private final class MentorQuestionRequest {
  private var task: Task<Void, Never>?
  private var ticket: GenerationTicket?
  var message: String?
  private(set) var processingProgress: String?
  var running: Bool { ticket != nil }

  func cancel(in store: UniCoachStore) {
    task?.cancel()
    if let ticket { store.cancel(ticket: ticket) }
    ticket = nil
    task = nil
    processingProgress = nil
  }

  func start(
    draft: ConsentDraft, in store: UniCoachStore, onAnswer: @escaping (MentorAnswer) -> Void
  ) {
    guard !running, modelAvailable() else { return }
    do {
      let request = try store.approve(draft: draft)
      let generation = try store.beginGeneration(for: request)
      ticket = generation
      task = Task { @MainActor in
        defer {
          store.cancel(ticket: generation)
          if ticket == generation {
            ticket = nil
            task = nil
            processingProgress = nil
          }
        }
        do {
          let answer = try await store.generateProcessedMentorAnswer(
            request: request, ticket: generation
          ) { input in
            #if compiler(>=6.2) && canImport(FoundationModels)
            if #available(iOS 26.0, *) {
              return try await generateAppleAnswer(
                input: input,
                checkCurrent: { try store.validateGeneration(request: request, ticket: generation) },
                progress: { progress in
                  guard ticket == generation else { return }
                  processingProgress = progress
                })
            }
            #endif
            throw UniCoachError.engineUnavailable
          }
          try Task.checkCancellation()
          guard ticket == generation else { return }
          onAnswer(answer)
        } catch is CancellationError {
          return
        } catch {
          guard ticket == generation else { return }
          message = error.localizedDescription + " Review your request and approve it again."
        }
      }
    } catch {
      message = error.localizedDescription + " Review your request and approve it again."
    }
  }
}

struct MentorAnswerDetail: View {
  let answer: MentorAnswer
  var body: some View {
    List {
      Section("Your question") {
        MentorSnapshotText(title: "Show full question", text: answer.question, identifier: "answer.question")
      }
      Section("Answer") {
        Text(answer.answer).textSelection(.enabled).accessibilityIdentifier("answer.text")
        Text("Check the mentor’s answer and any approved sources before relying on it.")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section("Request") {
        LabeledContent("Engine", value: answer.engine.displayName).accessibilityIdentifier("answer.engine")
        LabeledContent("Created", value: answer.createdAt.formatted())
      }
      Section("Approved source snapshots") {
        if answer.sources.isEmpty { Text("No private context selected.") }
        ForEach(answer.sources) { source in
          VStack(alignment: .leading) {
            Text(source.title).font(.headline)
            MentorSnapshotText(
              title: "Show approved text", text: source.text, identifier: "answer.source." + source.id)
          }
        }
      }
      Section(answer.processingSteps?.contains { $0.kind == .chunk } == true
        ? "Full approved request" : "Model request snapshot")
      {
        Text(answer.instructionsSnapshot).textSelection(.enabled)
        MentorSnapshotText(
          title: "Show full prompt", text: answer.promptSnapshot, identifier: "answer.prompt")
      }
      if let steps = answer.processingSteps, !steps.isEmpty { MentorProcessingAudit(steps: steps) }
    }.navigationTitle("Mentor answer")
  }
}
