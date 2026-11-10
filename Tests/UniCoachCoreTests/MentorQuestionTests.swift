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

  @MainActor func testCancelledNoContextTicketRejectsLateResponseAndDuplicateInvocation() async throws {
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
    draft.setSelected(true, source: try XCTUnwrap(store.contextSources().first { $0.id == first.id }))
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

  @MainActor private func makeStore() -> UniCoachStore {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    addTeardownBlock { try? FileManager.default.removeItem(at: url) }
    return UniCoachStore(fileURL: url)
  }
}
