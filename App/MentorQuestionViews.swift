#if compiler(>=6.2) && canImport(FoundationModels)
import FoundationModels
#endif
import SwiftUI
import UniCoachCore

struct MentorLanding: View {
  @Environment(AppState.self) private var app
  @State private var chosen: Assignment?
  @State private var asking = false
  @State private var deleting: MentorAnswer?

  var body: some View {
    List {
      Section {
        Text("Ask a question on its own, or review an assignment with its feedback.")
          .foregroundStyle(.secondary)
        Button("Ask your mentor") { asking = true }
          .accessibilityIdentifier("mentor.ask")
      }
      Section("Saved mentor answers") {
        if app.data.mentorAnswers.isEmpty {
          Text("Your saved answers will appear here.").foregroundStyle(.secondary)
        }
        ForEach(app.data.mentorAnswers) { answer in
          NavigationLink(answer.question) { MentorAnswerDetail(answer: answer) }
            .swipeActions { Button("Delete", role: .destructive) { deleting = answer } }
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
    .confirmationDialog("Delete this answer?", isPresented: Binding(
      get: { deleting != nil }, set: { if !$0 { deleting = nil } }
    ), titleVisibility: .visible) {
      Button("Delete answer", role: .destructive) {
        if let deleting { app.perform { try app.store.deleteMentorAnswer(id: deleting.id) } }
        deleting = nil
      }
    } message: { Text("This removes the saved answer and its request snapshots.") }
    .navigationTitle("AI Mentor")
    .sheet(item: $chosen) { MentorView(assignmentID: $0.id) }
    .sheet(isPresented: $asking) { MentorQuestionView() }
  }
}

struct MentorQuestionView: View {
  @Environment(AppState.self) private var app
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @State private var availabilityRevision = 0
  @State private var draft = ConsentDraft(purpose: .mentorQuestion)
  @FocusState private var focusedField: String?
  @State private var selectedApple = false
  @State private var running = false
  @State private var task: Task<Void, Never>?
  @State private var ticket: GenerationTicket?
  @State private var message: String?
  @State private var answer: MentorAnswer?

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
    NavigationStack {
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
          if running { Button("Cancel request", role: .cancel) { cancel() } }
        }
        if let answer {
          Section("Saved answer") {
            NavigationLink("View answer") { MentorAnswerDetail(answer: answer) }
              .accessibilityIdentifier("question.savedAnswer")
          }
        }
      }
      .navigationTitle("Ask your mentor")
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { focusedField = nil }.accessibilityIdentifier("question.keyboardDone")
        }
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { cancel(); dismiss() }
        }
      }
      .interactiveDismissDisabled(running)
      .alert("Mentor", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
        Button("OK") { message = nil }
      } message: { Text(message ?? "") }
    }.onChange(of: scenePhase) { _, phase in
      if phase == .active { availabilityRevision += 1 }
    }.onDisappear { cancel() }
  }

  private func cancel() {
    task?.cancel()
    if let ticket { app.store.cancel(ticket: ticket) }
    ticket = nil
    running = false
    draft = ConsentDraft(purpose: .mentorQuestion)
    selectedApple = false
  }

  private func start() {
    guard selectedApple, modelAvailable() else { return }
    draft.engine = .appleOnDevice
    do {
      let request = try app.store.approve(draft: draft)
      let generation = try app.store.beginGeneration(for: request)
      ticket = generation
      running = true
      task = Task { @MainActor in
        do {
          let result = try await app.store.generateMentorAnswer(request: request, ticket: generation) { input in
            #if compiler(>=6.2) && canImport(FoundationModels)
            if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable {
              let session = LanguageModelSession(instructions: input.instructions)
              return try await session.respond(to: input.prompt).content
            }
            #endif
            throw UniCoachError.engineUnavailable
          }
          try Task.checkCancellation()
          guard ticket?.id == generation.id else { return }
          answer = result
          ticket = nil
          running = false
          draft = ConsentDraft(purpose: .mentorQuestion)
          selectedApple = false
        } catch is CancellationError {
          app.store.cancel(ticket: generation)
          if ticket?.id == generation.id { cancel() }
        } catch {
          app.store.cancel(ticket: generation)
          if ticket?.id == generation.id {
            ticket = nil
            running = false
            selectedApple = false
            message = error.localizedDescription + " Review your request and try again."
          }
        }
      }
    } catch {
      selectedApple = false
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
        Text(answer.sources.isEmpty
          ? "This is general study guidance. Check the answer before relying on it."
          : "This is the model’s interpretation of your approved text. Check the answer and its sources before relying on it.")
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
