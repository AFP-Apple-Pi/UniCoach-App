import XCTest

@testable import UniCoachCore

final class MentorQuestionTests: XCTestCase {
  @MainActor func testQuestionApprovalRequiresQuestionWithinLimitAndApple() async throws {
    let store = makeStore()
    var draft = ConsentDraft(question: " \n\t", engine: .appleOnDevice, purpose: .mentorQuestion)
    XCTAssertThrowsError(try store.approve(draft: draft)) {
      XCTAssertEqual($0 as? UniCoachError, .invalidQuestion)
    }

    draft.question = String(repeating: "x", count: UniCoachStore.contextCharacterLimit)
    XCTAssertEqual(try store.approve(draft: draft).question, draft.question)
    draft.question += " "
    XCTAssertThrowsError(try store.approve(draft: draft)) {
      XCTAssertEqual($0 as? UniCoachError, .contextTooLong)
    }
    try store.saveProfile(.init(name: "Synthetic learner"))
    let source = try XCTUnwrap(store.contextSources().first { $0.id == "profile" })
    draft.question = "How can I plan a study session?"
    draft.setSelected(true, source: source)
    let remaining = UniCoachStore.contextCharacterLimit - draft.question.count
    draft.setText(String(repeating: "x", count: remaining), sourceID: source.id)
    XCTAssertEqual(try store.approve(draft: draft).sources.first?.text.count, remaining)
    draft.setText(String(repeating: "x", count: remaining + 1), sourceID: source.id)
    XCTAssertThrowsError(try store.approve(draft: draft)) {
      XCTAssertEqual($0 as? UniCoachError, .contextTooLong)
    }

    draft.engine = .contextualOffline
    XCTAssertThrowsError(try store.approve(draft: draft)) {
      XCTAssertEqual($0 as? UniCoachError, .engineUnavailable)
    }
    XCTAssertThrowsError(try store.approve(draft: ConsentDraft(question: draft.question))) {
      XCTAssertEqual($0 as? UniCoachError, .noSources)
    }
  }

  @MainActor func testNoContextSendsOnlyQuestionAndCannotBeReplayed() async throws {
    let store = makeStore()
    try store.saveProfile(.init(name: "Excluded learner name"))
    let question = "  How can I plan a study session?\n"
    let draft = ConsentDraft(question: question, engine: .appleOnDevice, purpose: .mentorQuestion)
    let request = try store.approve(draft: draft)
    XCTAssertTrue(request.sources.isEmpty)
    let ticket = try store.beginGeneration(for: request)
    XCTAssertThrowsError(try store.generateOffline(request: request)) {
      XCTAssertEqual($0 as? UniCoachError, .engineUnavailable)
    }
    XCTAssertThrowsError(
      try store.saveReport(
        request: request,
        output: .init(summary: "Unrelated", recommendations: [], evidenceSourceIDs: []),
        ticket: ticket)
    )

    let saved = try await store.generateMentorAnswer(request: request, ticket: ticket) { input in
      XCTAssertEqual(input.prompt, "Question:\n\(question)\n\nNo approved context was included.")
      XCTAssertTrue(input.conversationTurns.isEmpty)
      XCTAssertTrue(input.historyQuestions.isEmpty)
      try store.saveProfile(.init(name: "New excluded name"))
      return "  Start by choosing one topic.\n"
    }
    XCTAssertEqual(saved.engine, .appleOnDevice)
    XCTAssertEqual(saved.question, question)
    XCTAssertEqual(saved.answer, "  Start by choosing one topic.\n")
    XCTAssertTrue(saved.sources.isEmpty)
    XCTAssertNil(saved.assignmentID)
    XCTAssertEqual(store.data.mentorAnswers, [saved])
    XCTAssertTrue(store.data.reports.isEmpty)
    XCTAssertThrowsError(try store.beginGeneration(for: request)) {
      XCTAssertEqual($0 as? UniCoachError, .cancelled)
    }
  }

  @MainActor func testRedactedSnapshotsSurviveSourceDeletionAndKeepHistoricalData() async throws {
    let store = makeStore()
    let subject = Subject(name: "Synthetic subject")
    try store.upsertSubject(subject)
    let assignment = Assignment(
      subjectID: subject.id, brief: "Approved excerpt with excluded detail",
      reflection: "Unselected reflection")
    try store.upsertAssignment(assignment)
    try store.upsertGoal(.init(subjectID: subject.id, title: "Practise explaining reasoning"))
    let sources = store.contextSources(assignmentID: assignment.id)
    let brief = try XCTUnwrap(sources.first { $0.id.hasSuffix(":brief") })
    var reviewDraft = ConsentDraft(assignmentID: assignment.id)
    reviewDraft.setSelected(true, source: brief)
    let reviewRequest = try store.approve(draft: reviewDraft)
    let reviewTicket = try store.beginGeneration(for: reviewRequest)
    let report = try store.saveReport(
      request: reviewRequest, output: store.generateOffline(request: reviewRequest),
      ticket: reviewTicket, instructionsSnapshot: "Historical instructions",
      promptSnapshots: ["Historical prompt"])
    let previousData = UniCoachStore(fileURL: store.fileURL).data
    XCTAssertEqual(previousData, store.data)
    XCTAssertTrue(previousData.mentorAnswers.isEmpty)

    let question = "How can I start?"
    var draft = ConsentDraft(
      question: question, engine: .appleOnDevice, assignmentID: assignment.id,
      purpose: .mentorQuestion)
    XCTAssertTrue(draft.selectedSources.isEmpty)
    draft.setSelected(true, source: brief)
    let reflection = try XCTUnwrap(sources.first { $0.id.hasSuffix(":reflection") })
    draft.setSelected(true, source: reflection)
    draft.setSelected(false, source: reflection)
    draft.setText(" \t\n", sourceID: brief.id)
    XCTAssertThrowsError(try store.approve(draft: draft)) {
      XCTAssertEqual($0 as? UniCoachError, .emptySource)
    }
    let approvedText = "  Approved excerpt with [redacted] 😊\n"
    draft.setText(approvedText, sourceID: brief.id)
    let request = try store.approve(draft: draft)
    let ticket = try store.beginGeneration(for: request)
    var inputUsed: MentorQuestionInput?
    let answer = try await store.generateMentorAnswer(request: request, ticket: ticket) { input in
      inputUsed = input
      XCTAssertTrue(input.prompt.contains(approvedText))
      XCTAssertFalse(input.prompt.contains("excluded detail"))
      XCTAssertFalse(input.prompt.contains("Unselected reflection"))
      XCTAssertFalse(input.prompt.contains(assignment.id.uuidString))
      return "Make a short outline."
    }

    let input = try XCTUnwrap(inputUsed)
    XCTAssertEqual(answer.question, question)
    XCTAssertEqual(answer.assignmentID, assignment.id)
    XCTAssertEqual(answer.sources.map(\.text), [approvedText])
    XCTAssertEqual(answer.instructionsSnapshot, input.instructions)
    XCTAssertEqual(answer.promptSnapshot, input.prompt)
    try store.deleteAssignment(id: assignment.id)

    let reloaded = UniCoachStore(fileURL: store.fileURL)
    XCTAssertNil(reloaded.loadingError)
    XCTAssertEqual(reloaded.data.mentorAnswers, [answer])
    XCTAssertEqual(reloaded.data.reports, [report])
    XCTAssertEqual(reloaded.data.goals, previousData.goals)
    try reloaded.deleteMentorAnswer(id: answer.id)
    let afterDeletion = UniCoachStore(fileURL: store.fileURL).data
    XCTAssertTrue(afterDeletion.mentorAnswers.isEmpty)
    XCTAssertEqual(afterDeletion.reports, [report])
    XCTAssertEqual(afterDeletion.goals, previousData.goals)
  }

  @MainActor func testCancelledNoContextTicketRejectsLateResponseAndDuplicateInvocation()
    async throws
  {
    let store = makeStore()
    let draft = ConsentDraft(
      question: "Where should I start?", engine: .appleOnDevice, purpose: .mentorQuestion)
    let request = try store.approve(draft: draft)
    let ticket = try store.beginGeneration(for: request)
    let (started, signalStarted) = AsyncStream<Void>.makeStream()
    let (release, allowResponse) = AsyncStream<Void>.makeStream()
    let task = Task { @MainActor in
      defer { signalStarted.finish() }
      return try await store.generateMentorAnswer(request: request, ticket: ticket) { _ in
        signalStarted.yield(())
        var responses = release.makeAsyncIterator()
        _ = await responses.next()
        return "A late response after cancellation"
      }
    }
    var starts = started.makeAsyncIterator()
    let didStart: Void? = await starts.next()
    XCTAssertNotNil(didStart)

    do {
      try await store.generateMentorAnswer(request: request, ticket: ticket) { _ in
        XCTFail("Duplicate generation must not reach the Apple generator")
        return "Duplicate"
      }
      XCTFail("Expected duplicate invocation to fail")
    } catch {
      XCTAssertEqual(error as? UniCoachError, .cancelled)
    }
    store.cancel(ticket: ticket)
    allowResponse.yield(())
    allowResponse.finish()
    do {
      _ = try await task.value
      XCTFail("Expected the late response to be rejected")
    } catch {
      XCTAssertEqual(error as? UniCoachError, .cancelled)
    }
    XCTAssertTrue(store.data.mentorAnswers.isEmpty)
    XCTAssertThrowsError(try store.beginGeneration(for: request)) {
      XCTAssertEqual($0 as? UniCoachError, .cancelled)
    }
  }

  @MainActor func testTaskCancellationRejectsAnswerEvenWhenGeneratorReturns() async throws {
    let store = makeStore()
    let request = try store.approve(
      draft: ConsentDraft(
        question: "Where should I start?", engine: .appleOnDevice, purpose: .mentorQuestion))
    let ticket = try store.beginGeneration(for: request)
    let task = Task { @MainActor in
      try await store.generateMentorAnswer(request: request, ticket: ticket) { _ in
        withUnsafeCurrentTask { $0?.cancel() }
        return "A generator response after task cancellation"
      }
    }
    do {
      _ = try await task.value
      XCTFail("Expected task cancellation to prevent saving")
    } catch is CancellationError {
      XCTAssertTrue(store.data.mentorAnswers.isEmpty)
    }
    XCTAssertThrowsError(try store.beginGeneration(for: request)) {
      XCTAssertEqual($0 as? UniCoachError, .cancelled)
    }
  }

  @MainActor func testSelectedSourceRevisionsPreventModelUseAndSavingAfterChanges() async throws {
    let store = makeStore()
    try store.saveProfile(.init(name: "Example learner"))
    var draft = ConsentDraft(
      question: "How should I study?", engine: .appleOnDevice, purpose: .mentorQuestion)
    let first = try XCTUnwrap(store.contextSources().first { $0.id == "profile" })
    draft.setSelected(true, source: first)
    let request = try store.approve(draft: draft)
    let ticket = try store.beginGeneration(for: request)
    try store.saveProfile(.init(name: "Changed learner"))
    try store.saveProfile(.init(name: "Example learner"))

    do {
      try await store.generateMentorAnswer(request: request, ticket: ticket) { _ in
        XCTFail("Stale context must not reach the Apple generator")
        return "Stale"
      }
      XCTFail("Expected stale approved context to fail")
    } catch {
      XCTAssertEqual(error as? UniCoachError, .sourceChanged)
    }

    draft.setSelected(false, source: first)
    draft.setSelected(
      true, source: try XCTUnwrap(store.contextSources().first { $0.id == first.id }))
    let nextRequest = try store.approve(draft: draft)
    let nextTicket = try store.beginGeneration(for: nextRequest)
    do {
      try await store.generateMentorAnswer(request: nextRequest, ticket: nextTicket) { _ in
        try store.saveProfile(.init(name: "Changed during generation"))
        return "Stale"
      }
      XCTFail("Expected the stale response to be rejected")
    } catch {
      XCTAssertEqual(error as? UniCoachError, .sourceChanged)
    }
    XCTAssertTrue(store.data.mentorAnswers.isEmpty)
  }

  @MainActor func testNoContextAssignmentAnchorInvalidatesDuringGeneration() async throws {
    let store = makeStore()
    let subject = Subject(name: "Synthetic subject")
    try store.upsertSubject(subject)
    let assignment = Assignment(subjectID: subject.id)
    try store.upsertAssignment(assignment)
    let request = try store.approve(
      draft: ConsentDraft(
        question: "How can I start this assignment?", engine: .appleOnDevice,
        assignmentID: assignment.id, purpose: .mentorQuestion))
    XCTAssertTrue(request.sources.isEmpty)
    let ticket = try store.beginGeneration(for: request)
    do {
      try await store.generateMentorAnswer(request: request, ticket: ticket) { _ in
        try store.deleteAssignment(id: assignment.id)
        return "Start with the brief."
      }
      XCTFail("Expected deletion of the assignment anchor to prevent saving")
    } catch {
      XCTAssertEqual(error as? UniCoachError, .sourceChanged)
    }
    XCTAssertTrue(store.data.mentorAnswers.isEmpty)
  }

  @MainActor func testUnavailableAppleGeneratorDoesNotSaveOrReplay() async throws {
    let store = makeStore()
    let request = try store.approve(
      draft: ConsentDraft(
        question: "How can I plan my work?", engine: .appleOnDevice, purpose: .mentorQuestion))
    let ticket = try store.beginGeneration(for: request)
    do {
      try await store.generateMentorAnswer(request: request, ticket: ticket) { _ in
        throw UniCoachError.engineUnavailable
      }
      XCTFail("Expected Apple availability failure to propagate")
    } catch {
      XCTAssertEqual(error as? UniCoachError, .engineUnavailable)
    }
    XCTAssertTrue(store.data.mentorAnswers.isEmpty)
    XCTAssertThrowsError(try store.beginGeneration(for: request)) {
      XCTAssertEqual($0 as? UniCoachError, .cancelled)
    }
  }

  @MainActor func testWhitespaceAnswerDoesNotSave() async throws {
    let store = makeStore()
    let draft = ConsentDraft(
      question: "How can I plan my work?", engine: .appleOnDevice, purpose: .mentorQuestion)
    let request = try store.approve(draft: draft)
    let ticket = try store.beginGeneration(for: request)
    do {
      try await store.generateMentorAnswer(request: request, ticket: ticket) { _ in " \n\t" }
      XCTFail("Expected a whitespace answer to fail")
    } catch {
      XCTAssertEqual(error as? UniCoachError, .emptyAnswer)
    }
    XCTAssertTrue(store.data.mentorAnswers.isEmpty)
  }

  func testLegacyRequestDefaultsToFeedbackReview() throws {
    let legacy = """
      {"id":"11111111-1111-1111-1111-111111111111","createdAt":1000,"question":"","engine":"contextualOffline","sources":[]}
      """
    let decoded = try JSONDecoder().decode(ApprovedRequest.self, from: Data(legacy.utf8))
    XCTAssertEqual(decoded.purpose, .feedbackReview)
  }

  @MainActor func testConversationConsentPersistenceIsolationAndDeletion() async throws {
    let store = makeStore()
    try store.saveProfile(.init(name: "Private synthetic source"))
    var firstDraft = ConsentDraft(
      question: "First question", engine: .appleOnDevice, purpose: .mentorQuestion)
    firstDraft.setSelected(true, source: try XCTUnwrap(store.contextSources().first))
    let firstRequest = try store.approve(draft: firstDraft)
    let first = try await store.generateMentorAnswer(
      request: firstRequest, ticket: store.beginGeneration(for: firstRequest)
    ) { _ in "First answer" }
    let snapshot = try store.conversationSnapshot(id: first.threadID)
    XCTAssertEqual(snapshot.transcript, "Question:\nFirst question\n\nMentor:\nFirst answer")
    let followup = ConsentDraft(
      question: "Second question", engine: .appleOnDevice, purpose: .mentorQuestion,
      conversation: snapshot)
    let request = try store.approve(draft: followup)
    let second = try await store.generateMentorAnswer(
      request: request, ticket: store.beginGeneration(for: request)
    ) { input in
      XCTAssertTrue(input.prompt.contains("Turn 1 student: \"First question\""))
      XCTAssertTrue(input.prompt.contains("Turn 1 mentor: \"First answer\""))
      XCTAssertTrue(input.prompt.hasSuffix("Current student request:\n\"Second question\""))
      XCTAssertEqual(input.currentQuestion, "Second question")
      XCTAssertEqual(input.conversationTurns, snapshot.turns)
      XCTAssertEqual(input.historyQuestions, ["First question"])
      XCTAssertTrue(input.sources.isEmpty)
      XCTAssertFalse(input.prompt.contains("Private synthetic source"))
      return "Second answer"
    }
    XCTAssertEqual(second.threadID, first.id)
    XCTAssertEqual(second.approvedConversation, snapshot)
    XCTAssertTrue(second.sources.isEmpty)
    let reopened = UniCoachStore(fileURL: store.fileURL)
    XCTAssertEqual(reopened.conversationAnswers(id: first.id), [first, second])
    XCTAssertEqual(
      try reopened.conversationSnapshot(id: first.id).turns.map(\.answerID), [first.id, second.id])
    try reopened.deleteMentorConversation(id: first.id)
    XCTAssertTrue(UniCoachStore(fileURL: store.fileURL).data.mentorAnswers.isEmpty)
    XCTAssertThrowsError(try reopened.conversationSnapshot(id: first.id))
  }

  @MainActor func testConcurrentRepliesAndDeletedTurnRejectStaleSnapshots() async throws {
    let store = makeStore()
    let rootRequest = try store.approve(
      draft: ConsentDraft(question: "Root", engine: .appleOnDevice, purpose: .mentorQuestion))
    let root = try await store.generateMentorAnswer(
      request: rootRequest, ticket: store.beginGeneration(for: rootRequest)
    ) { _ in "Root answer" }
    let snapshot = try store.conversationSnapshot(id: root.id)
    let draft = ConsentDraft(
      question: "Follow up", engine: .appleOnDevice, purpose: .mentorQuestion,
      conversation: snapshot)
    let firstRequest = try store.approve(draft: draft)
    let secondRequest = try store.approve(draft: draft)
    let firstTicket = try store.beginGeneration(for: firstRequest)
    let secondTicket = try store.beginGeneration(for: secondRequest)
    let (started, signalStarted) = AsyncStream<Void>.makeStream()
    let (release, allowResponse) = AsyncStream<Void>.makeStream()
    let late = Task { @MainActor in
      try await store.generateMentorAnswer(request: secondRequest, ticket: secondTicket) { _ in
        signalStarted.yield(())
        var iterator = release.makeAsyncIterator()
        _ = await iterator.next()
        return "Late answer"
      }
    }
    var iterator = started.makeAsyncIterator()
    _ = await iterator.next()
    _ = try await store.generateMentorAnswer(request: firstRequest, ticket: firstTicket) { _ in
      "First reply"
    }
    allowResponse.yield(())
    allowResponse.finish()
    do {
      _ = try await late.value
      XCTFail("Stale reply must not save")
    } catch { XCTAssertEqual(error as? UniCoachError, .sourceChanged) }
    XCTAssertEqual(store.conversationAnswers(id: root.id).count, 2)
    XCTAssertThrowsError(try store.approve(draft: draft)) {
      XCTAssertEqual($0 as? UniCoachError, .sourceChanged)
    }
    let updated = try store.conversationSnapshot(id: root.id)
    let updatedRequest = try store.approve(
      draft: ConsentDraft(
        question: "Next", engine: .appleOnDevice, purpose: .mentorQuestion, conversation: updated))
    try store.deleteMentorAnswer(id: root.id)
    XCTAssertThrowsError(try store.beginGeneration(for: updatedRequest)) {
      XCTAssertEqual($0 as? UniCoachError, .sourceChanged)
    }
  }

  @MainActor func testCancelledFollowupCannotSaveLateAnswer() async throws {
    let store = makeStore()
    let rootRequest = try store.approve(
      draft: ConsentDraft(question: "Root", engine: .appleOnDevice, purpose: .mentorQuestion))
    let root = try await store.generateMentorAnswer(
      request: rootRequest, ticket: store.beginGeneration(for: rootRequest)
    ) { _ in "Root answer" }
    let snapshot = try store.conversationSnapshot(id: root.id)
    let request = try store.approve(
      draft: ConsentDraft(
        question: "Follow up", engine: .appleOnDevice, purpose: .mentorQuestion,
        conversation: snapshot))
    let ticket = try store.beginGeneration(for: request)
    do {
      _ = try await store.generateMentorAnswer(request: request, ticket: ticket) { _ in
        store.cancel(ticket: ticket)
        return "Late answer"
      }
      XCTFail("Cancelled follow-up must not save")
    } catch { XCTAssertEqual(error as? UniCoachError, .cancelled) }
    XCTAssertEqual(try store.conversationSnapshot(id: root.id), snapshot)
    XCTAssertThrowsError(try store.beginGeneration(for: request))
  }

  @MainActor func testConversationLimitAndFailedRetryRequiresFreshApproval() async throws {
    let store = makeStore()
    let rootRequest = try store.approve(
      draft: ConsentDraft(question: "Root", engine: .appleOnDevice, purpose: .mentorQuestion))
    let root = try await store.generateMentorAnswer(
      request: rootRequest, ticket: store.beginGeneration(for: rootRequest)
    ) { _ in "Answer" }
    let snapshot = try store.conversationSnapshot(id: root.id)
    var draft = ConsentDraft(
      question: String(
        repeating: "x", count: UniCoachStore.contextCharacterLimit - snapshot.transcript.count),
      engine: .appleOnDevice, purpose: .mentorQuestion, conversation: snapshot)
    _ = try store.approve(draft: draft)
    draft.question += "x"
    XCTAssertThrowsError(try store.approve(draft: draft)) {
      XCTAssertEqual($0 as? UniCoachError, .contextTooLong)
    }
    draft.question = "Retry"
    let failed = try store.approve(draft: draft)
    do {
      _ = try await store.generateMentorAnswer(
        request: failed, ticket: store.beginGeneration(for: failed)
      ) { _ in throw UniCoachError.engineUnavailable }
      XCTFail("Expected failure")
    } catch { XCTAssertEqual(error as? UniCoachError, .engineUnavailable) }
    XCTAssertThrowsError(try store.beginGeneration(for: failed))
    let retry = try store.approve(draft: draft)
    _ = try await store.generateMentorAnswer(
      request: retry, ticket: store.beginGeneration(for: retry)
    ) { _ in "Recovered" }
    XCTAssertEqual(store.conversationAnswers(id: root.id).count, 2)
  }

  @MainActor func testLegacyAnswerWithoutConversationFieldsDecodesAsRoot() async throws {
    let store = makeStore()
    let request = try store.approve(
      draft: ConsentDraft(
        question: "Old question", engine: .appleOnDevice, purpose: .mentorQuestion))
    let saved = try await store.generateMentorAnswer(
      request: request, ticket: store.beginGeneration(for: request)
    ) { _ in "Old answer" }
    let encoded = try JSONEncoder().encode(saved)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object.removeValue(forKey: "conversationID")
    object.removeValue(forKey: "approvedConversation")
    let legacy = try JSONSerialization.data(withJSONObject: object)
    let decoded = try JSONDecoder().decode(MentorAnswer.self, from: legacy)
    XCTAssertNil(decoded.conversationID)
    XCTAssertNil(decoded.approvedConversation)
    XCTAssertEqual(decoded.threadID, decoded.id)
  }

  @MainActor func testIndependentThreadsAndFreshDraftDoNotShareHistory() async throws {
    let store = makeStore()
    func ask(_ question: String, _ answer: String) async throws -> MentorAnswer {
      let draft = ConsentDraft(question: question, engine: .appleOnDevice, purpose: .mentorQuestion)
      XCTAssertNil(draft.conversation)
      let request = try store.approve(draft: draft)
      return try await store.generateMentorAnswer(
        request: request, ticket: store.beginGeneration(for: request)
      ) { input in
        XCTAssertFalse(input.prompt.contains("Thread A"))
        XCTAssertFalse(input.prompt.contains("Thread B"))
        return answer
      }
    }
    let a = try await ask("First", "Thread A")
    _ = try await ask("Second", "Thread B")
    let snapshot = try store.conversationSnapshot(id: a.id)
    let request = try store.approve(
      draft: ConsentDraft(
        question: "Reply", engine: .appleOnDevice, purpose: .mentorQuestion, conversation: snapshot)
    )
    _ = try await store.generateMentorAnswer(
      request: request, ticket: store.beginGeneration(for: request)
    ) { input in
      XCTAssertTrue(input.prompt.contains("Thread A"))
      XCTAssertFalse(input.prompt.contains("Thread B"))
      return "Reply A"
    }
    _ = try await ask("Fresh", "Fresh answer")
  }

  @MainActor func testApprovedRolesKeepMentorOfferSeparateFromStudentConstraints() async throws {
    let store = makeStore()
    let firstRequest = try store.approve(draft: ConsentDraft(question: "Help me revise", engine: .appleOnDevice, purpose: .mentorQuestion))
    let first = try await store.generateMentorAnswer(request: firstRequest, ticket: store.beginGeneration(for: firstRequest)) { _ in
      "I can outline two 45 minute sessions."
    }
    let snapshot = try store.conversationSnapshot(id: first.id)
    let request = try store.approve(draft: ConsentDraft(question: "Yes", engine: .appleOnDevice, purpose: .mentorQuestion, conversation: snapshot))
    _ = try await store.generateMentorAnswer(request: request, ticket: store.beginGeneration(for: request)) { input in
      XCTAssertEqual(input.conversationTurns, snapshot.turns)
      XCTAssertEqual(input.historyQuestions, ["Help me revise"])
      XCTAssertTrue(input.routingPrompt.contains("mentor: \"I can outline two 45 minute sessions.\""))
      XCTAssertTrue(input.routingPrompt.hasSuffix("Current student request:\n\"Yes\""))
      XCTAssertFalse(input.currentTurnPrompt.contains("45 minute"))
      XCTAssertTrue(input.currentTurnPrompt.hasSuffix("No additional source context was included."))
      let proposed = StudyPlanConstraint(kind: .minutesPerSession, relation: .exact, value: 45, evidence: "45 minute", numberText: "45", unit: .minutes, origin: .history)
      XCTAssertFalse(StudyPlanValidator.constraintsAreGrounded([proposed], currentQuestion: input.currentQuestion, historyQuestions: input.historyQuestions))
      return "Here is a starting point."
    }
  }

  func testNoQuestionGuardAndAuditLegacyDecoding() throws {
    for text in ["What should I do?", "Would you like a plan", "Tell me your schedule", "Please share your work", "How much time is available", "Ready؟", "If helpful, let me know your schedule."] {
      XCTAssertTrue(MentorResponsePolicy.containsQuestion(text), text)
    }
    for text in ["Start with a short review.", "Your schedule can guide the next step.", "The feedback mentions a clear argument.", "What you need is a clear goal.", "How you organise evidence matters."] {
      XCTAssertFalse(MentorResponsePolicy.containsQuestion(text), text)
    }
    let old = """
      {"kind":"final","instructions":"i","prompt":"p","output":"o","provenance":[]}
      """
    let decoded = try JSONDecoder().decode(ModelProcessingStep.self, from: Data(old.utf8))
    XCTAssertNil(decoded.conversationTurns)
    let turn = MentorConversationTurn(answerID: UUID(), question: "Question", answer: "Answer")
    let step = ModelProcessingStep(kind: .final, instructions: "i", prompt: "p", output: "o", conversationTurns: [turn])
    XCTAssertEqual(try JSONDecoder().decode(ModelProcessingStep.self, from: JSONEncoder().encode(step)), step)
  }

  @MainActor func testDeletingConversationDuringGenerationCannotResurrectIt() async throws {
    let store = makeStore()
    let rootRequest = try store.approve(
      draft: ConsentDraft(question: "Root", engine: .appleOnDevice, purpose: .mentorQuestion))
    let root = try await store.generateMentorAnswer(
      request: rootRequest, ticket: store.beginGeneration(for: rootRequest)
    ) { _ in "Answer" }
    let snapshot = try store.conversationSnapshot(id: root.id)
    let request = try store.approve(
      draft: ConsentDraft(
        question: "Reply", engine: .appleOnDevice, purpose: .mentorQuestion, conversation: snapshot)
    )
    do {
      _ = try await store.generateMentorAnswer(
        request: request, ticket: store.beginGeneration(for: request)
      ) { _ in
        try store.deleteMentorConversation(id: root.id)
        return "Late answer"
      }
      XCTFail("Deleted conversation must not be restored")
    } catch { XCTAssertEqual(error as? UniCoachError, .sourceChanged) }
    XCTAssertTrue(store.conversationAnswers(id: root.id).isEmpty)
  }

  @MainActor func testHistoryWithFreshSourceLimitAndDeletedOldSource() async throws {
    let store = makeStore()
    let subject = Subject(name: "Synthetic")
    try store.upsertSubject(subject)
    let assignment = Assignment(subjectID: subject.id, brief: "Old private material")
    try store.upsertAssignment(assignment)
    let old = try XCTUnwrap(store.contextSources().first { $0.id.hasSuffix(":brief") })
    var rootDraft = ConsentDraft(question: "Root", engine: .appleOnDevice, purpose: .mentorQuestion)
    rootDraft.setSelected(true, source: old)
    let rootRequest = try store.approve(draft: rootDraft)
    let root = try await store.generateMentorAnswer(
      request: rootRequest, ticket: store.beginGeneration(for: rootRequest)
    ) { _ in "Answer" }
    try store.deleteAssignment(id: assignment.id)
    try store.saveProfile(.init(name: "Fresh material"))
    let snapshot = try store.conversationSnapshot(id: root.id)
    let fresh = try XCTUnwrap(store.contextSources().first { $0.id == "profile" })
    var draft = ConsentDraft(
      question: "Next", engine: .appleOnDevice, purpose: .mentorQuestion, conversation: snapshot)
    draft.setSelected(true, source: fresh)
    let remaining =
      UniCoachStore.contextCharacterLimit - snapshot.transcript.count - draft.question.count
    draft.setText(String(repeating: "x", count: remaining), sourceID: fresh.id)
    _ = try store.approve(draft: draft)
    draft.setText(String(repeating: "x", count: remaining + 1), sourceID: fresh.id)
    XCTAssertThrowsError(try store.approve(draft: draft)) {
      XCTAssertEqual($0 as? UniCoachError, .contextTooLong)
    }
    draft.setSelected(false, source: fresh)
    let request = try store.approve(draft: draft)
    _ = try await store.generateMentorAnswer(
      request: request, ticket: store.beginGeneration(for: request)
    ) { input in
      XCTAssertFalse(input.prompt.contains("Old private material"))
      return "Follow-up answer"
    }
  }

  @MainActor private func makeStore() -> UniCoachStore {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    addTeardownBlock { try? FileManager.default.removeItem(at: url) }
    return UniCoachStore(fileURL: url)
  }
}
