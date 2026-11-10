import XCTest
@testable import UniCoachCore

final class AssignmentDesignTests: XCTestCase {
  @MainActor func testNewFieldsPersistAndGuidedReflectionRequiresSelection() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let store = UniCoachStore(fileURL: url)
    let subject = Subject(code: "SYN", name: "Synthetic", credits: 6, semester: "Spring", description: "Synthetic description")
    try store.upsertSubject(subject)
    let assignment = Assignment(subjectID: subject.id, title: "Synthetic task", brief: "Synthetic brief", tutorFeedback: "Synthetic feedback", reflection: "Private all in one", submittedWork: "Synthetic work", score: 12, outOf: 20, collaborationType: "Group work", assignmentFormat: "Report", targetGrade: "Distinction", weighting: 30, currentStage: "Stage private", approach: "Method private", challenges: "Challenge private", collaboration: "Team private", rubric: "Rubric private")
    try store.upsertAssignment(assignment)
    let restored = UniCoachStore(fileURL: url)
    XCTAssertEqual(restored.data.subjects.first, subject)
    XCTAssertEqual(restored.data.assignments.first, assignment)
    XCTAssertEqual(restored.subjectMarks(subjectID: subject.id).percentage, 60)
    let subjectSource = try XCTUnwrap(restored.contextSources().first { $0.id == "subject:\(subject.id.uuidString)" })
    XCTAssertTrue(subjectSource.text.contains("Description: Synthetic description"))
    let source = try XCTUnwrap(restored.contextSources(assignmentID: assignment.id).first { $0.id.hasSuffix(":guided-reflection") })
    XCTAssertTrue(source.text.contains("Stage private"))
    XCTAssertTrue(source.text.contains("Rubric private"))
    var draft = ConsentDraft(question: "Help", engine: .appleOnDevice, purpose: .mentorQuestion)
    let withoutSelection = try restored.approve(draft: draft)
    XCTAssertTrue(withoutSelection.sources.isEmpty)
    draft.setSelected(true, source: source)
    let selected = try restored.approve(draft: draft)
    XCTAssertEqual(selected.sources.map(\.text), [source.text])
    XCTAssertFalse(selected.sources[0].text.contains("Private all in one"))
  }

  @MainActor func testWeightingBoundariesDoNotChangeMarks() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let store = UniCoachStore(fileURL: url)
    let subject = Subject(name: "Synthetic")
    try store.upsertSubject(subject)
    var assignment = Assignment(subjectID: subject.id, title: "Task", score: 12, outOf: 20)
    for value: Double? in [nil, 0, 100] {
      assignment.weighting = value
      try store.upsertAssignment(assignment)
      XCTAssertEqual(store.data.assignments.first?.weighting, value)
      XCTAssertEqual(store.subjectMarks(subjectID: subject.id).score, 12)
      XCTAssertEqual(store.subjectMarks(subjectID: subject.id).outOf, 20)
    }
    let saved = try XCTUnwrap(store.data.assignments.first)
    for value in [-1.0, 100.1, Double.infinity, -Double.infinity, Double.nan] {
      assignment.weighting = value
      XCTAssertThrowsError(try store.upsertAssignment(assignment)) {
        XCTAssertEqual($0 as? UniCoachError, .invalidGrade)
      }
      XCTAssertEqual(store.data.assignments.first, saved)
    }
  }

  func testLegacyRecordsDecodeWithoutNewFields() throws {
    let subject = """
      {"id":"11111111-1111-1111-1111-111111111111","code":"S","name":"Subject","credits":6,"tutor":"","colorHex":"#123456","isDemo":false}
      """
    let assignment = """
      {"id":"22222222-2222-2222-2222-222222222222","subjectID":"11111111-1111-1111-1111-111111111111","title":"Task","brief":"","tutorFeedback":"","reflection":"Original reflection","isDemo":false}
      """
    let oldSubject = try JSONDecoder().decode(Subject.self, from: Data(subject.utf8))
    let oldAssignment = try JSONDecoder().decode(Assignment.self, from: Data(assignment.utf8))
    XCTAssertEqual(oldSubject.description, "")
    XCTAssertNil(oldAssignment.weighting)
    XCTAssertEqual(oldAssignment.reflection, "Original reflection")
    XCTAssertEqual(oldAssignment.currentStage, "")
    XCTAssertEqual(try JSONDecoder().decode(Subject.self, from: JSONEncoder().encode(oldSubject)), oldSubject)
    XCTAssertEqual(try JSONDecoder().decode(Assignment.self, from: JSONEncoder().encode(oldAssignment)), oldAssignment)
  }
}
