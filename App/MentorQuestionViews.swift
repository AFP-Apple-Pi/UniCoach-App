#if compiler(>=6.2) && canImport(FoundationModels)
import FoundationModels
#endif
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
              Text(conversation.question)
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
  @State private var conversationID: UUID?
  @State private var request = MentorQuestionRequest()

  init(conversationID: UUID?) {
    _conversationID = State(initialValue: conversationID)
  }

  var body: some View {
    NavigationStack {
      Group {
        if let conversationID {
          MentorConversationView(conversationID: conversationID, request: request) {
            self.conversationID = nil
          }
        } else {
          MentorQuestionView(request: request) { answer in
            conversationID = answer.threadID
          }
        }
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            request.cancel(in: app.store)
            dismiss()
          }
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
    .interactiveDismissDisabled(request.running)
    .onDisappear { request.cancel(in: app.store) }
    .alert("Mentor", isPresented: Binding(
      get: { request.message != nil }, set: { if !$0 { request.message = nil } }
    )) {
      Button("OK") { request.message = nil }
    } message: { Text(request.message ?? "") }
  }
}

private struct MentorQuestionView: View {
  @Environment(AppState.self) private var app
  @Environment(\.scenePhase) private var scenePhase
  @State private var availabilityRevision = 0
  @State private var draft = ConsentDraft(purpose: .mentorQuestion)
  @FocusState private var focusedField: String?
  @State private var selectedApple = false

  let request: MentorQuestionRequest
  let onAnswer: (MentorAnswer) -> Void

  private var running: Bool { request.running }

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

  var body: some View {
    Form {
      Section("1. Your question") {
        TextField("What would you like help with?", text: $draft.question, axis: .vertical)
          .focused($focusedField, equals: "question")
          .accessibilityIdentifier("question.text")
        Text("Try a starter, then edit it to make it your own.")
          .font(.caption).foregroundStyle(.secondary)
        Button("How can I plan my study time?") {
          draft.question = "How can I plan my study time?"
        }.accessibilityIdentifier("question.starter")
        Button("How can I improve my next assignment?") {
          draft.question = "How can I improve my next assignment?"
        }
      }.disabled(running)
      Section("2. Optional private context") {
        Text("Only your question and selected text are used. Apple processes this request on device, with no prior conversation history.")
          .font(.caption).foregroundStyle(.secondary)
        Text("Nothing is selected for you. Select only what you want to share for this request.")
          .font(.caption).foregroundStyle(.secondary)
        ForEach(app.store.contextSources()) { source in
          Toggle(sourceTitle(source), isOn: Binding(
            get: { draft.selectedSources.contains { $0.id == source.id } },
            set: { selected in
              var approvedSource = source
              approvedSource.title = sourceTitle(source)
              draft.setSelected(selected, source: approvedSource)
            }
          )).accessibilityIdentifier("question.source." + source.id)
        }
      }.disabled(running)
      Section("3. Review exact request") {
        Text("Question").font(.headline)
        Text(draft.question.isEmpty ? "Enter a question above." : draft.question)
          .textSelection(.enabled).accessibilityIdentifier("question.preview")
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
            .focused($focusedField, equals: source.id)
            .accessibilityLabel("Approved text for " + source.title)
            .frame(minHeight: 100)
          }
        }
        Text("Your question and selected text are limited to 6,000 characters. Nothing is silently omitted.")
          .font(.caption).foregroundStyle(.secondary)
      }.disabled(running)
      Section("4. Choose Apple on-device AI") {
        Text(modelAvailability()).font(.subheadline).foregroundStyle(.secondary)
          .id(availabilityRevision).accessibilityIdentifier("question.availability")
        Toggle("Use Apple on-device AI for this request", isOn: $selectedApple)
          .accessibilityIdentifier("question.apple")
        Text("The answer may be inaccurate. Check it before relying on it.")
          .font(.caption).foregroundStyle(.secondary)
      }.disabled(running)
      Section {
        Button(running ? "Working..." : "Approve and ask") { start() }
          .accessibilityIdentifier("question.approve")
          .disabled(running || !selectedApple || !modelAvailable()
            || draft.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        if running {
          Button("Cancel request", role: .cancel) {
            request.cancel(in: app.store)
            draft = ConsentDraft(purpose: .mentorQuestion)
          }
        }
      }
    }
    .navigationTitle("Ask your mentor")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { focusedField = nil }.accessibilityIdentifier("question.keyboardDone")
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { availabilityRevision += 1 }
    }
  }

  private func start() {
    guard selectedApple, modelAvailable() else { return }
    var approvedDraft = draft
    approvedDraft.engine = .appleOnDevice
    selectedApple = false
    focusedField = nil
    request.start(draft: approvedDraft, in: app.store, onAnswer: onAnswer)
  }
}

private struct MentorConversationView: View {
  @Environment(AppState.self) private var app
  @Environment(\.scenePhase) private var scenePhase
  @State private var availabilityRevision = 0
  @State private var reply = ""
  @State private var visibleTurn: UUID?

  let conversationID: UUID
  let request: MentorQuestionRequest
  let onNew: () -> Void

  var body: some View {
    Group {
      if let history = try? app.store.conversationSnapshot(id: conversationID) {
        let answers = app.store.conversationAnswers(id: conversationID)
        ScrollView {
          LazyVStack(alignment: .leading) {
            ForEach(Array(answers.enumerated()), id: \.element.id) { index, answer in
              MentorConversationTurnView(answer: answer, index: index)
                .disabled(request.running)
            }
            DisclosureGroup("Review exact conversation history") {
              Text(history.transcript)
                .textSelection(.enabled)
                .accessibilityIdentifier("conversation.history")
            }
          }
          .scrollTargetLayout()
          .padding()
        }
        .scrollPosition(id: $visibleTurn, anchor: .top)
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("conversation.transcript")
        .onChange(of: answers.last?.id, initial: true) { _, id in visibleTurn = id }
        .safeAreaInset(edge: .bottom, spacing: 0) {
          MentorReplyComposer(
            reply: $reply, historyLength: history.transcript.count, running: request.running,
            available: modelAvailable(), availabilityMessage: modelAvailability(),
            availabilityRevision: availabilityRevision,
            onApprove: { send(approving: history) },
            onCancel: { request.cancel(in: app.store) })
        }
      } else {
        ContentUnavailableView("Conversation unavailable", systemImage: "bubble.left")
      }
    }
    .navigationTitle("Conversation")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("New conversation", systemImage: "square.and.pencil", action: onNew)
          .labelStyle(.iconOnly)
          .accessibilityIdentifier("conversation.new")
          .disabled(request.running)
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { availabilityRevision += 1 }
    }
    .onDisappear { request.cancel(in: app.store) }
  }

  private func send(approving history: MentorConversationSnapshot) {
    var draft = ConsentDraft(purpose: .mentorQuestion)
    draft.question = reply
    draft.engine = .appleOnDevice
    draft.conversation = history
    request.start(draft: draft, in: app.store) { _ in reply = "" }
  }
}

private struct MentorConversationTurnView: View {
  let answer: MentorAnswer
  let index: Int

  var body: some View {
    VStack(alignment: .leading) {
      VStack(alignment: .leading) {
        Text("You").font(.caption).foregroundStyle(.secondary)
        Text(answer.question)
          .textSelection(.enabled)
          .accessibilityIdentifier("conversation.question.\(index)")
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
      .background(lavender, in: .rect(cornerRadius: 14))
      VStack(alignment: .leading) {
        Text("Mentor").font(.caption).foregroundStyle(.secondary)
        Text(answer.answer)
          .textSelection(.enabled)
          .accessibilityIdentifier("conversation.answer.\(index)")
        NavigationLink("Request details", value: answer.id)
          .font(.footnote)
          .accessibilityIdentifier("conversation.request.\(index)")
      }
      .padding()
    }
  }
}

private struct MentorReplyComposer: View {
  @Binding var reply: String
  @FocusState private var focused: Bool
  let historyLength: Int
  let running: Bool
  let available: Bool
  let availabilityMessage: String
  let availabilityRevision: Int
  let onApprove: () -> Void
  let onCancel: () -> Void

  private var limitReached: Bool {
    let limit = UniCoachStore.contextCharacterLimit
    return historyLength >= limit || historyLength + reply.count > limit
  }

  var body: some View {
    VStack(alignment: .leading) {
      Divider()
      TextField("Reply to your mentor", text: $reply, axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .lineLimit(1...4)
        .focused($focused)
        .disabled(running)
        .accessibilityIdentifier("conversation.reply")
      Text("Apple on-device AI uses the messages above and your reply. Earlier private source snapshots are excluded. Visible messages may repeat details from them.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("conversation.disclosure")
      if limitReached {
        Text("Conversation and reply must fit within 6,000 characters. Shorten your reply or start a new conversation to ask without this history.")
          .font(.caption)
          .accessibilityIdentifier("conversation.limit")
      }
      if !available {
        Text(availabilityMessage)
          .font(.caption)
          .id(availabilityRevision)
          .accessibilityIdentifier("conversation.availability")
      }
      if running {
        ProgressView("Waiting for your mentor...")
        Button("Cancel request", role: .cancel, action: onCancel)
      } else {
        Button("Approve conversation and send") {
          focused = false
          onApprove()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!available || limitReached || reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .accessibilityIdentifier("conversation.send")
      }
    }
    .padding([.horizontal, .bottom])
    .background(.regularMaterial)
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") { focused = false }.accessibilityIdentifier("conversation.keyboardDone")
      }
    }
  }
}

@MainActor @Observable
private final class MentorQuestionRequest {
  private var task: Task<Void, Never>?
  private var ticket: GenerationTicket?
  var message: String?
  var running: Bool { ticket != nil }

  func cancel(in store: UniCoachStore) {
    task?.cancel()
    if let ticket { store.cancel(ticket: ticket) }
    ticket = nil
    task = nil
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
          }
        }
        do {
          let answer = try await store.generateMentorAnswer(request: request, ticket: generation) { input in
            #if compiler(>=6.2) && canImport(FoundationModels)
            if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable {
              let session = LanguageModelSession(instructions: input.instructions)
              return try await session.respond(to: input.prompt).content
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
      Section("Your question") { Text(answer.question).textSelection(.enabled).accessibilityIdentifier("answer.question") }
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
            Text(source.text).textSelection(.enabled)
          }
        }
      }
      Section("Model request snapshot") {
        Text(answer.instructionsSnapshot).textSelection(.enabled)
        Text(answer.promptSnapshot).textSelection(.enabled).accessibilityIdentifier("answer.prompt")
      }
    }.navigationTitle("Mentor answer")
  }
}
