import XCTest
@testable import UniCoachCore

final class UniCoachCoreTests: XCTestCase {
    func testPersistenceAndGrades() async throws { try await MainActor.run {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("data.json")
        let store = UniCoachStore(fileURL: url)
        try store.saveProfile(.init(name: "A"))
        let subject = Subject(name: "Math")
        try store.upsertSubject(subject)
        try store.upsertAssignment(.init(subjectID: subject.id, grade: 80))
        try store.upsertAssignment(.init(subjectID: subject.id))
        try store.upsertAssignment(.init(subjectID: subject.id, grade: 20, isDemo: true))
        XCTAssertEqual(store.data.averageGrade, 80)
        let reloaded = UniCoachStore(fileURL: url)
        XCTAssertEqual(reloaded.data, store.data)
        try reloaded.deleteSubject(id: subject.id)
        XCTAssertTrue(reloaded.data.assignments.isEmpty)
    } }
    func testConsentRedactionAndHistory() async throws { try await MainActor.run {
        let store = UniCoachStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let subject = Subject(name: "Secret title"); try store.upsertSubject(subject)
        let assignment = Assignment(subjectID: subject.id, title: "Private name", brief: "PUBLIC private secret", reflection: "hidden reflection")
        try store.upsertAssignment(assignment)
        let sources = store.contextSources(assignmentID: assignment.id)
        var draft = ConsentDraft()
        XCTAssertTrue(draft.selectedSources.isEmpty)
        XCTAssertThrowsError(try store.approve(draft: draft))
        let source = try XCTUnwrap(sources.first { $0.id.hasSuffix(":brief") })
        draft.setSelected(true, source: source); draft.setText("PUBLIC [redacted]", sourceID: source.id)
        let request = try store.approve(draft: draft)
        XCTAssertEqual(request.sources.map(\.text), ["PUBLIC [redacted]"])
        let ticket = try store.beginGeneration(for: request)
        let output = try store.generateOffline(request: request)
        XCTAssertTrue(output.summary.contains("not AI"))
        XCTAssertTrue(output.recommendations.joined().contains("PUBLIC [redacted]"))
        XCTAssertFalse(output.recommendations.joined().contains("private secret"))
        let report = try store.saveReport(request: request, output: output, ticket: ticket)
        try store.deleteSubject(id: subject.id)
        XCTAssertEqual(store.data.reports.first, report)
        XCTAssertEqual(store.data.reports.first?.sources.first?.text, "PUBLIC [redacted]")
    } }
    func testStaleCancelBindingAndEvidence() async throws { try await MainActor.run {
        let store = UniCoachStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let subject = Subject(name: "S"); try store.upsertSubject(subject)
        var assignment = Assignment(subjectID: subject.id, title: "A", brief: "Brief"); try store.upsertAssignment(assignment)
        let source = try XCTUnwrap(store.contextSources().first { $0.id.hasSuffix(":brief") })
        var draft = ConsentDraft(); draft.setSelected(true, source: source)
        assignment.title = "Changed"; try store.upsertAssignment(assignment)
        XCTAssertThrowsError(try store.approve(draft: draft))
        draft = ConsentDraft(); draft.setSelected(true, source: try XCTUnwrap(store.contextSources().first { $0.id == source.id }))
        let request = try store.approve(draft: draft)
        let ticket = try store.beginGeneration(for: request)
        let other = try store.approve(draft: draft)
        let output = try store.generateOffline(request: request)
        XCTAssertThrowsError(try store.saveReport(request: other, output: output, ticket: ticket))
        let cancelledRequest = try store.approve(draft: draft)
        let cancelled = try store.beginGeneration(for: cancelledRequest); store.cancel(ticket: cancelled)
        XCTAssertThrowsError(try store.saveReport(request: cancelledRequest, output: output, ticket: cancelled))
        let badRequest = try store.approve(draft: draft)
        let bad = try store.beginGeneration(for: badRequest)
        XCTAssertThrowsError(try store.saveReport(request: badRequest, output: .init(summary: "x", recommendations: [], evidenceSourceIDs: ["unknown"]), ticket: bad))
        let staleRequest = try store.approve(draft: draft)
        let stale = try store.beginGeneration(for: staleRequest)
        assignment.grade = 70; try store.upsertAssignment(assignment)
        assignment.grade = nil; try store.upsertAssignment(assignment)
        XCTAssertThrowsError(try store.saveReport(request: staleRequest, output: output, ticket: stale))
        var refreshed = ConsentDraft(); refreshed.setSelected(true, source: try XCTUnwrap(store.contextSources().first { $0.id == source.id }))
        let deletedRequest = try store.approve(draft: refreshed)
        let deletedTicket = try store.beginGeneration(for: deletedRequest)
        let deletedOutput = try store.generateOffline(request: deletedRequest)
        try store.deleteAssignment(id: assignment.id)
        XCTAssertThrowsError(try store.saveReport(request: deletedRequest, output: deletedOutput, ticket: deletedTicket))
        XCTAssertTrue(store.data.reports.isEmpty)
    } }
    func testFailedAndCorruptPersistenceDoesNotPublish() async throws { try await MainActor.run {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let corrupt = dir.appendingPathComponent("corrupt.json"); let original = Data("bad".utf8); try original.write(to: corrupt)
        let store = UniCoachStore(fileURL: corrupt); XCTAssertNotNil(store.loadingError)
        XCTAssertThrowsError(try store.saveProfile(.init(name: "new")))
        XCTAssertEqual(try Data(contentsOf: corrupt), original); XCTAssertEqual(store.data.profile.name, "")
        let broken = UniCoachStore(fileURL: dir.appendingPathComponent("missing/../corrupt.json/child"))
        XCTAssertThrowsError(try broken.saveProfile(.init(name: "new")))
        XCTAssertEqual(broken.data.profile.name, "")
    } }
}

extension UniCoachCoreTests {
    func testConsentDeselectionOptionalQuestionAndLimit() async throws { try await MainActor.run {
        let store = UniCoachStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        try store.saveProfile(.init(name: "Learner"))
        let source = try XCTUnwrap(store.contextSources().first)
        var draft = ConsentDraft(); draft.setSelected(true, source: source); draft.setSelected(false, source: source)
        XCTAssertTrue(draft.selectedSources.isEmpty); XCTAssertThrowsError(try store.approve(draft: draft))
        draft.setSelected(true, source: source)
        XCTAssertEqual(try store.approve(draft: draft).question, "")
        draft.setText(String(repeating: "x", count: UniCoachStore.contextCharacterLimit + 1), sourceID: source.id)
        XCTAssertThrowsError(try store.approve(draft: draft)) { XCTAssertEqual($0 as? UniCoachError, .contextTooLong) }
    } }
    func testOfflineUsesEveryApprovedSource() async throws { try await MainActor.run {
        let store = UniCoachStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        try store.saveProfile(.init(name: "Learner"))
        try store.upsertGoal(.init(title: "Read more"))
        var draft = ConsentDraft()
        for source in store.contextSources() { draft.setSelected(true, source: source) }
        let request = try store.approve(draft: draft); let output = try store.generateOffline(request: request)
        XCTAssertEqual(output.evidenceSourceIDs, request.sources.map(\.id))
        XCTAssertTrue(output.recommendations[0].contains("[S1]")); XCTAssertTrue(output.recommendations[1].contains("[S2]"))
        for source in request.sources { XCTAssertTrue(output.recommendations.joined().contains(source.text)) }
    } }
    func testGoalCRUDInvalidGradesAndFullProfileRoundTrip() async throws { try await MainActor.run {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = UniCoachStore(fileURL: url)
        let profile = AcademicProfile(name: "A", university: "U", course: "C", learningGoal: "G", onboardingComplete: true)
        try store.saveProfile(profile); let subject = Subject(name: "S"); try store.upsertSubject(subject)
        var goal = LearningGoal(subjectID: subject.id, title: "Read"); try store.upsertGoal(goal)
        goal.isCompleted = true; try store.upsertGoal(goal); XCTAssertTrue(try XCTUnwrap(store.data.goals.first { $0.id == goal.id }).isCompleted)
        XCTAssertThrowsError(try store.upsertAssignment(.init(subjectID: subject.id, grade: -1)))
        XCTAssertThrowsError(try store.upsertAssignment(.init(subjectID: subject.id, grade: 101)))
        XCTAssertEqual(UniCoachStore(fileURL: url).data.profile.name, profile.name)
        XCTAssertEqual(UniCoachStore(fileURL: url).data.goals.filter { $0.subjectID == nil }.map(\.title), [profile.learningGoal])
        try store.deleteGoal(id: goal.id); XCTAssertFalse(store.data.goals.contains { $0.id == goal.id })
    } }
    func testApprovalIsSingleUseAfterCancellationOrSave() async throws { try await MainActor.run {
        let store = UniCoachStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        try store.saveProfile(.init(name: "A")); var draft = ConsentDraft()
        draft.setSelected(true, source: try XCTUnwrap(store.contextSources().first))
        let cancelled = try store.approve(draft: draft); let ticket = try store.beginGeneration(for: cancelled)
        XCTAssertThrowsError(try store.beginGeneration(for: cancelled)); store.cancel(ticket: ticket)
        XCTAssertThrowsError(try store.beginGeneration(for: cancelled))
        let saved = try store.approve(draft: draft); let next = try store.beginGeneration(for: saved)
        try store.saveReport(request: saved, output: store.generateOffline(request: saved), ticket: next)
        XCTAssertThrowsError(try store.beginGeneration(for: saved))
    } }
    func testAssignmentAnchorInvalidatesUnrelatedSourceRequest() async throws { try await MainActor.run {
        let store = UniCoachStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        try store.saveProfile(.init(name: "A")); let subject = Subject(name: "S"); try store.upsertSubject(subject)
        var assignment = Assignment(subjectID: subject.id, title: "A"); try store.upsertAssignment(assignment)
        var draft = ConsentDraft(); draft.setSelected(true, source: try XCTUnwrap(store.contextSources().first { $0.id == "profile" }))
        let request = try store.approve(draft: draft, assignmentID: assignment.id)
        let ticket = try store.beginGeneration(for: request); let output = try store.generateOffline(request: request)
        assignment.title = "B"; try store.upsertAssignment(assignment); assignment.title = "A"; try store.upsertAssignment(assignment)
        XCTAssertThrowsError(try store.saveReport(request: request, output: output, ticket: ticket))
        let next = try store.approve(draft: draft, assignmentID: assignment.id); let nextTicket = try store.beginGeneration(for: next)
        try store.deleteAssignment(id: assignment.id)
        XCTAssertThrowsError(try store.saveReport(request: next, output: output, ticket: nextTicket))
    } }
}

extension UniCoachCoreTests {
    func testPromptSnapshotRoundTripAndLegacyDecode() async throws { try await MainActor.run {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = UniCoachStore(fileURL: url); try store.saveProfile(.init(name: "Learner"))
        var draft = ConsentDraft(); let source = try XCTUnwrap(store.contextSources().first)
        draft.setSelected(true, source: source); draft.setText("approved redacted", sourceID: source.id)
        let request = try store.approve(draft: draft); let ticket = try store.beginGeneration(for: request)
        let report = try store.saveReport(request: request, output: store.generateOffline(request: request), ticket: ticket, instructionsSnapshot: "Original instructions", promptSnapshots: ["approved redacted"])
        try store.saveProfile(.init(name: "Changed"))
        let loaded = try XCTUnwrap(UniCoachStore(fileURL: url).data.reports.first)
        XCTAssertEqual(loaded, report); XCTAssertEqual(loaded.instructionsSnapshot, "Original instructions"); XCTAssertEqual(loaded.promptSnapshots, ["approved redacted"])
        let encoded = try JSONEncoder().encode(report)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacy.removeValue(forKey: "instructionsSnapshot"); legacy.removeValue(forKey: "promptSnapshots")
        let oldReport = try JSONDecoder().decode(MentorReport.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(oldReport.instructionsSnapshot); XCTAssertTrue(oldReport.promptSnapshots.isEmpty)
    } }
}

extension UniCoachCoreTests {
    func testReportDeletionPersistsWithoutChangingRecordsOrOtherReports() async throws { try await MainActor.run {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = UniCoachStore(fileURL: url); try store.saveProfile(.init(name: "Learner"))
        let subject = Subject(name: "Subject"); try store.upsertSubject(subject)
        let assignment = Assignment(subjectID: subject.id, title: "Assignment", brief: "Brief"); try store.upsertAssignment(assignment)
        var draft = ConsentDraft(); draft.setSelected(true, source: try XCTUnwrap(store.contextSources().first))
        @MainActor func generate() throws -> MentorReport {
            let request = try store.approve(draft: draft); let ticket = try store.beginGeneration(for: request)
            return try store.saveReport(request: request, output: store.generateOffline(request: request), ticket: ticket)
        }
        let first = try generate(); let second = try generate(); let records = store.data
        try store.deleteReport(id: first.id)
        let reloaded = UniCoachStore(fileURL: url).data
        XCTAssertEqual(reloaded.reports, [second]); XCTAssertEqual(reloaded.profile, records.profile)
        XCTAssertEqual(reloaded.subjects, records.subjects); XCTAssertEqual(reloaded.assignments, records.assignments); XCTAssertEqual(reloaded.goals, records.goals)
    } }
}
