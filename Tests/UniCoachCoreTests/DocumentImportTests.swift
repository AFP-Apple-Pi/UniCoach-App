import XCTest
@testable import UniCoachCore

final class DocumentImportTests: XCTestCase {
  func testOutlineAndAtomicLink() async throws {
    let text = """
    55501 Interaction Prototyping
    Delivery: Spring Session 2026
    Credit Points: 6
    Subject Description
    Practice design.
    Subject Learning Outcomes
    Assessment task 1: Prototype plan
    Description: Build a plan.
    Type: Report
    Groupwork: Group, individually assessed
    Weight: 30%
    Due: 2026-11-27
    """
    let draft = DocumentImportParser.parse(sourceName: "outline.png", pages: [.init(number: 1, text: text)])
    XCTAssertEqual(draft.subject.code, "55501")
    XCTAssertEqual(draft.subject.name, "Interaction Prototyping")
    XCTAssertEqual(draft.assignments.count, 1)
    let item = try XCTUnwrap(draft.assignments.first)
    XCTAssertEqual(item.weighting, 30)
    XCTAssertEqual(item.collaborationType, "Group")
    XCTAssertNotNil(item.dueDate)
    XCTAssertNil(item.score)
    XCTAssertEqual(item.sourceReferences.first?.pageNumbers, [1])
    try await MainActor.run {
      let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("data.json")
      let store = UniCoachStore(fileURL: file)
      var edited = item
      edited.tutorFeedback = "must not be imported"
      let id = try store.commitDocumentImport(subject: draft.subject, assignments: [edited], existingSubjectID: nil, updateExistingSubject: false, allowDuplicates: false)
      var duplicate = draft.subject
      duplicate.semester = "Spring 2026"
      XCTAssertEqual(store.matchingImportSubjects(duplicate).count, 1)
      XCTAssertEqual(store.data.assignments.first?.subjectID, id)
      XCTAssertEqual(store.data.assignments.first?.tutorFeedback, "")
      XCTAssertThrowsError(try store.commitDocumentImport(subject: draft.subject, assignments: [edited], existingSubjectID: nil, updateExistingSubject: false, allowDuplicates: false))
      XCTAssertEqual(UniCoachStore(fileURL: file).data, store.data)
    }
  }
}
