import Foundation
import XCTest
@testable import UniCoachCore

final class AlphaContractTests: XCTestCase {
  @MainActor func testLatePersistenceFailurePreservesDataAndRequiresFreshApproval() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "data.json")
    let backup = directory.appending(path: "synthetic-backup.json")
    let store = UniCoachStore(fileURL: url)
    try store.saveProfile(.init(name: "Synthetic learner"))
    let beforeData = store.data
    let beforeBytes = try Data(contentsOf: url)
    let draft = ConsentDraft(question: "How can I plan?", engine: .appleOnDevice, purpose: .mentorQuestion)
    let request = try store.approve(draft: draft)
    let ticket = try store.beginGeneration(for: request)
    do {
      _ = try await store.generateProcessedMentorAnswer(request: request, ticket: ticket) { _ in
        try FileManager.default.moveItem(at: url, to: backup)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return MentorGenerationResult(answer: "Synthetic answer", steps: [])
      }
      XCTFail("A failed commit must not publish an answer")
    } catch { XCTAssertFalse(error is CancellationError) }
    XCTAssertEqual(store.data, beforeData)
    XCTAssertEqual(try Data(contentsOf: backup), beforeBytes)
    XCTAssertThrowsError(try store.beginGeneration(for: request)) {
      XCTAssertEqual($0 as? UniCoachError, .cancelled)
    }
    try FileManager.default.removeItem(at: url)
    try FileManager.default.moveItem(at: backup, to: url)
    let retry = try store.approve(draft: draft)
    let saved = try await store.generateMentorAnswer(request: retry, ticket: store.beginGeneration(for: retry)) { _ in "Retry answer" }
    XCTAssertEqual(UniCoachStore(fileURL: url).data.mentorAnswers, [saved])
  }

  @MainActor func testModifiedApprovalAndForeignTicketNeverReachGenerator() async throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let store = UniCoachStore(fileURL: url)
    let draft = ConsentDraft(question: "Original question", engine: .appleOnDevice, purpose: .mentorQuestion)
    let approved = try store.approve(draft: draft)
    let ticket = try store.beginGeneration(for: approved)
    let modified = ApprovedRequest(id: approved.id, createdAt: approved.createdAt, question: "Altered question", engine: .appleOnDevice, sources: [], purpose: .mentorQuestion)
    for pair in [(modified, ticket), (approved, GenerationTicket(requestID: UUID()))] {
      do {
        _ = try await store.generateProcessedMentorAnswer(request: pair.0, ticket: pair.1) { _ in
          XCTFail("Unapproved request reached generator")
          return MentorGenerationResult(answer: "Unexpected", steps: [])
        }
        XCTFail("Mismatched request must fail")
      } catch { XCTAssertEqual(error as? UniCoachError, .cancelled) }
    }
    let saved = try await store.generateMentorAnswer(request: approved, ticket: ticket) { _ in "Approved answer" }
    XCTAssertEqual(saved.question, "Original question")
    XCTAssertEqual(store.data.mentorAnswers.count, 1)
  }

  @MainActor func testUnrelatedAssignmentEditDoesNotInvalidateSelectedSource() async throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let store = UniCoachStore(fileURL: url)
    let subject = Subject(name: "Synthetic subject")
    try store.upsertSubject(subject)
    let selectedAssignment = Assignment(subjectID: subject.id, brief: "Selected synthetic brief")
    var unrelated = Assignment(subjectID: subject.id, brief: "Unselected synthetic brief")
    try store.upsertAssignment(selectedAssignment)
    try store.upsertAssignment(unrelated)
    let source = try XCTUnwrap(store.contextSources().first { $0.id == "assignment:\(selectedAssignment.id.uuidString):brief" })
    var draft = ConsentDraft(question: "Explain this", engine: .appleOnDevice, purpose: .mentorQuestion)
    draft.setSelected(true, source: source)
    draft.setText("Selected [redacted] brief", sourceID: source.id)
    let request = try store.approve(draft: draft)
    let ticket = try store.beginGeneration(for: request)
    unrelated.brief = "Edited unselected brief"
    try store.upsertAssignment(unrelated)
    let answer = try await store.generateMentorAnswer(request: request, ticket: ticket) { input in
      XCTAssertTrue(input.prompt.contains("Selected [redacted] brief"))
      XCTAssertFalse(input.prompt.contains("Edited unselected brief"))
      return "Synthetic answer"
    }
    XCTAssertEqual(answer.sources.map(\.text), ["Selected [redacted] brief"])
  }

  @MainActor func testMultiLevelReductionPreservesCompleteOriginalProvenance() async throws {
    let original = String(repeating: "synthetic source paragraph ", count: 400)
    let result = try await LongContextProcessor.prepare(
      instructions: "Original instructions", prompt: original, responseBudget: 100,
      fits: { _, text, _, final in final ? text.count <= 190 : text.count <= 300 },
      generate: { _, input, _ in input.count > 100 ? String(repeating: "n", count: 40) : "short note" },
      checkCurrent: {})
    let chunks = result.steps.filter { $0.kind == .chunk }
    let reductions = result.steps.filter { $0.kind == .reduction }
    XCTAssertGreaterThan(reductions.count, 1)
    XCTAssertEqual(chunks.map(\.prompt).joined(), original)
    let allRanges = chunks.flatMap(\.provenance)
    XCTAssertEqual(allRanges.first?.location, 0)
    XCTAssertEqual(allRanges.reduce(0) { $0 + $1.length }, original.utf16.count)
    XCTAssertEqual(reductions.last?.provenance, allRanges)
    XCTAssertTrue(result.steps.allSatisfy { $0.responseBudget == 256 && $0.schemaSnapshot == nil })
    XCTAssertNotNil(result.notes)
  }

  @MainActor func testFailedIntermediateProcessingDoesNotSavePartialAnswerOrReuseApproval() async throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let store = UniCoachStore(fileURL: url)
    let request = try store.approve(draft: ConsentDraft(question: String(repeating: "q", count: 1200), engine: .appleOnDevice, purpose: .mentorQuestion))
    let ticket = try store.beginGeneration(for: request)
    var calls = 0
    do {
      _ = try await store.generateProcessedMentorAnswer(request: request, ticket: ticket) { input in
        _ = try await LongContextProcessor.prepare(instructions: input.instructions, prompt: input.prompt, responseBudget: 100,
          fits: { _, prompt, _, final in !final && prompt.count <= 400 },
          generate: { _, _, _ in calls += 1; if calls == 2 { throw UniCoachError.engineUnavailable }; return "partial note" },
          checkCurrent: { try store.validateGeneration(request: request, ticket: ticket) })
        XCTFail("Final generation must not run after a failed chunk")
        return MentorGenerationResult(answer: "Unexpected", steps: [])
      }
      XCTFail("Expected intermediate failure")
    } catch { XCTAssertEqual(error as? UniCoachError, .engineUnavailable) }
    XCTAssertEqual(calls, 2)
    XCTAssertTrue(store.data.mentorAnswers.isEmpty)
    XCTAssertThrowsError(try store.beginGeneration(for: request)) { XCTAssertEqual($0 as? UniCoachError, .cancelled) }
  }
  @MainActor func testDuplicateIdentifiersFailClosedWithoutChangingFile() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let answerStore = UniCoachStore(fileURL: directory.appending(path: "answer-source.json"))
    let answerRequest = try answerStore.approve(draft: ConsentDraft(question: "Synthetic question", engine: .appleOnDevice, purpose: .mentorQuestion))
    let answer = try await answerStore.generateMentorAnswer(request: answerRequest, ticket: answerStore.beginGeneration(for: answerRequest)) { _ in "Synthetic answer" }
    let subject = Subject(name: "Synthetic subject")
    let assignment = Assignment(subjectID: subject.id, title: "Synthetic assignment")
    let goal = LearningGoal(subjectID: subject.id, title: "Synthetic goal")
    let report = MentorReport(question: "", engine: .appleOnDevice, sources: [], output: .init(summary: "Synthetic", recommendations: [], evidenceSourceIDs: []))
    let cases = [
      AppData(subjects: [subject, subject]),
      AppData(assignments: [assignment, assignment]),
      AppData(goals: [goal, goal]),
      AppData(reports: [report, report]),
      AppData(mentorAnswers: [answer, answer]),
    ]
    for (index, malformed) in cases.enumerated() {
      let url = directory.appending(path: "duplicate-\(index).json")
      let original = try JSONEncoder().encode(malformed)
      try original.write(to: url)
      let store = UniCoachStore(fileURL: url)
      XCTAssertNotNil(store.loadingError, "Duplicate IDs in collection \(index) must fail to load")
      XCTAssertEqual(store.data, AppData())
      XCTAssertThrowsError(try store.saveProfile(.init(name: "Must not save")))
      XCTAssertThrowsError(try store.deleteSubject(id: subject.id))
      XCTAssertEqual(try Data(contentsOf: url), original)
    }
  }

  @MainActor func testSubjectCreditsRejectInvalidValuesWithoutChangingSavedRecord() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "data.json")
    let store = UniCoachStore(fileURL: url)
    var subject = Subject(name: "Synthetic subject")
    for credits in [0.0, 6.0, 2.5] {
      subject.credits = credits
      try store.upsertSubject(subject)
      XCTAssertEqual(store.data.subjects.first?.credits, credits)
      XCTAssertEqual(UniCoachStore(fileURL: url).data.subjects.first?.credits, credits)
    }
    let before = try Data(contentsOf: url)
    let saved = store.data
    for credits in [-1.0, Double.nan, Double.infinity, -Double.infinity] {
      subject.credits = credits
      XCTAssertThrowsError(try store.upsertSubject(subject)) {
        XCTAssertEqual($0 as? UniCoachError, .invalidCredits)
      }
      XCTAssertEqual(store.data, saved)
      XCTAssertEqual(try Data(contentsOf: url), before)
    }
  }

  @MainActor func testFutureSchemaIsPreservedAndNeverOverwritten() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let current = try JSONEncoder().encode(AppData(profile: .init(name: "Synthetic")))
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: current) as? [String: Any])
    object["schemaVersion"] = AppData.currentSchemaVersion + 1
    object["futureField"] = ["preserve": "synthetic"]
    let original = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    try original.write(to: url)
    let store = UniCoachStore(fileURL: url)
    XCTAssertNotNil(store.loadingError)
    XCTAssertEqual(try Data(contentsOf: url), original)
    XCTAssertThrowsError(try store.saveProfile(.init(name: "Must not save")))
    XCTAssertThrowsError(try store.upsertSubject(.init(name: "Must not save")))
    XCTAssertEqual(try Data(contentsOf: url), original)
  }

  @MainActor func testDeletingSubjectRetainsHistoricalReportAndLinkedGoal() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let store = UniCoachStore(fileURL: url)
    let subject = Subject(name: "Synthetic subject")
    try store.upsertSubject(subject)
    let assignment = Assignment(subjectID: subject.id, tutorFeedback: "Synthetic feedback", submittedWork: "Synthetic work")
    try store.upsertAssignment(assignment)
    let standalone = LearningGoal(subjectID: subject.id, title: "Subject-only goal")
    try store.upsertGoal(standalone)
    var draft = ConsentDraft(engine: .appleOnDevice, assignmentID: assignment.id)
    for source in store.contextSources(assignmentID: assignment.id)
    where source.id.hasSuffix(":work") || source.id.hasSuffix(":feedback") {
      draft.setSelected(true, source: source)
    }
    let request = try store.approve(draft: draft)
    let ticket = try store.beginGeneration(for: request)
    let output = MentorOutput(summary: "Synthetic historical output", recommendations: [], evidenceSourceIDs: request.sources.map(\.id))
    let report = try store.saveReport(request: request, output: output, ticket: ticket, instructionsSnapshot: "Synthetic instructions", promptSnapshots: ["Synthetic prompt"])
    var linked = LearningGoal(subjectID: subject.id, title: "Linked goal", sourceReportID: report.id, originAssignmentID: assignment.id)
    try store.upsertGoal(linked)
    try store.deleteSubject(id: subject.id)
    XCTAssertTrue(store.data.subjects.isEmpty)
    XCTAssertTrue(store.data.assignments.isEmpty)
    XCTAssertFalse(store.data.goals.contains { $0.id == standalone.id })
    XCTAssertEqual(store.data.reports, [report])
    XCTAssertEqual(store.data.goals.first { $0.id == linked.id }, linked)
    linked.title = "Updated linked goal"
    try store.upsertGoal(linked)
    let reopened = UniCoachStore(fileURL: url)
    XCTAssertNil(reopened.loadingError)
    XCTAssertEqual(reopened.data.reports, [report])
    XCTAssertEqual(reopened.data.goals.first { $0.id == linked.id }?.title, linked.title)
    XCTAssertEqual(reopened.data.reports.first?.sources, request.sources)
  }

}
