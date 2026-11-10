import XCTest
@testable import UniCoachCore

final class AppleOnlyReviewTests: XCTestCase {
  @MainActor func testAppleReviewCannotUseOfflineGenerator() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let store = UniCoachStore(fileURL: url)
    let subject = Subject(name: "Synthetic")
    try store.upsertSubject(subject)
    let assignment = Assignment(subjectID: subject.id, tutorFeedback: "Synthetic feedback.", submittedWork: "Synthetic work.")
    try store.upsertAssignment(assignment)
    var draft = ConsentDraft(engine: .appleOnDevice, assignmentID: assignment.id)
    for source in store.contextSources(assignmentID: assignment.id)
    where source.id.hasSuffix(":work") || source.id.hasSuffix(":feedback") {
      draft.setSelected(true, source: source)
    }
    let request = try store.approve(draft: draft)
    XCTAssertEqual(request.engine, .appleOnDevice)
    XCTAssertThrowsError(try store.generateOffline(request: request)) {
      XCTAssertEqual($0 as? UniCoachError, .engineUnavailable)
    }
    XCTAssertTrue(store.data.reports.isEmpty)
  }

  func testHistoricalOfflineReportStillDecodes() throws {
    let legacy = """
      {"id":"11111111-1111-1111-1111-111111111111","createdAt":1000,"question":"","engine":"contextualOffline","sources":[],"output":{"summary":"Historical synthetic report","recommendations":[],"evidenceSourceIDs":[]}}
      """
    let report = try JSONDecoder().decode(MentorReport.self, from: Data(legacy.utf8))
    XCTAssertEqual(report.engine, .contextualOffline)
    XCTAssertEqual(report.output.summary, "Historical synthetic report")
    XCTAssertEqual(try JSONDecoder().decode(MentorReport.self, from: JSONEncoder().encode(report)), report)
  }
}
