import XCTest

@testable import UniCoachCore

final class JointReviewTests: XCTestCase {
  func testCompleteLegacyFixtureLoadsAndSurvivesSave() async throws {
    try await MainActor.run {
      let json = """
        {"profile":{"name":"Lee","university":"Uni","course":"Arts","learningGoal":"Write","onboardingComplete":true},"subjects":[{"id":"11111111-1111-1111-1111-111111111111","code":"ART1","name":"Art","credits":6,"tutor":"Tutor","colorHex":"#123456","academicGoal":"Learn","isDemo":false}],"assignments":[{"id":"22222222-2222-2222-2222-222222222222","subjectID":"11111111-1111-1111-1111-111111111111","title":"Essay","brief":"Brief","dueDate":1000,"grade":72,"tutorFeedback":"Feedback","reflection":"Reflection","isDemo":false}],"goals":[{"id":"33333333-3333-3333-3333-333333333333","subjectID":"11111111-1111-1111-1111-111111111111","title":"Goal","isCompleted":true}],"reports":[{"id":"44444444-4444-4444-4444-444444444444","createdAt":2000,"question":"Question","engine":"appleOnDevice","sources":[{"id":"profile","title":"Academic profile","text":"Approved","originalFingerprint":"abc"}],"output":{"summary":"Summary","recommendations":["Next"],"evidenceSourceIDs":["profile"]},"assignmentID":"22222222-2222-2222-2222-222222222222","instructionsSnapshot":"Instruction","promptSnapshots":["Prompt"]}]}
        """
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      try Data(json.utf8).write(to: url)
      let store = UniCoachStore(fileURL: url)
      XCTAssertNil(store.loadingError)
      XCTAssertEqual(store.data.assignments.first?.submittedWork, "")
      XCTAssertEqual(store.data.reports.first?.promptSnapshots, ["Prompt"])
      XCTAssertNil(store.data.reports.first?.output.findings)
      XCTAssertTrue(store.data.focusActions.isEmpty)
      let before = store.data
      try store.saveProfile(before.profile)
      XCTAssertEqual(UniCoachStore(fileURL: url).data, before)
    }
  }

  func testPassagesPreserveApprovedUnicodeAndRejectWrongAnchors() async throws {
    try await MainActor.run {
      let store = UniCoachStore(
        fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
      let subject = Subject(name: "S")
      try store.upsertSubject(subject)
      let work =
        String(repeating: "An example sentence with evidence. ", count: 12) + "😀 café final"
      let assignment = Assignment(
        subjectID: subject.id, tutorFeedback: "😀 Explain the link.", submittedWork: work)
      let other = Assignment(
        subjectID: subject.id, tutorFeedback: "Other feedback", submittedWork: "Other work")
      try store.upsertAssignment(assignment)
      try store.upsertAssignment(other)
      var draft = ConsentDraft(assignmentID: assignment.id)
      for source in store.contextSources()
      where source.id.contains(assignment.id.uuidString) || source.id.contains(other.id.uuidString)
      {
        if source.id.hasSuffix(":work") || source.id.hasSuffix(":feedback") {
          draft.setSelected(true, source: source)
        }
      }
      let request = try store.approve(draft: draft)
      let passages = store.evidencePassages(request: request)
      let workPassages = passages.filter { $0.sourceID.hasSuffix(":work") }
      let feedback = try XCTUnwrap(passages.first { $0.sourceID.hasSuffix(":feedback") })
      XCTAssertEqual(workPassages.map(\.quote).joined(), work)
      XCTAssertTrue(workPassages.dropLast().allSatisfy { $0.quote.last?.isWhitespace == true })
      for passage in passages {
        let source = try XCTUnwrap(request.sources.first { $0.id == passage.sourceID })
        let range = try XCTUnwrap(
          Range(NSRange(location: passage.location, length: passage.length), in: source.text))
        XCTAssertEqual(String(source.text[range]), passage.quote)
      }
      let valid = try store.resolveFinding(
        request: request, category: .improve, explanation: "Explain the link",
        nextStep: "Add a sentence", workPassageID: workPassages[0].passageID,
        feedbackPassageID: feedback.passageID)
      XCTAssertThrowsError(
        try store.resolveFinding(
          request: request, category: .improve, explanation: "x", nextStep: "x",
          workPassageID: feedback.passageID, feedbackPassageID: workPassages[0].passageID))
      let otherID = "assignment:\(other.id.uuidString):work:0:10"
      XCTAssertThrowsError(
        try store.resolveFinding(
          request: request, category: .improve, explanation: "x", nextStep: "x",
          workPassageID: otherID, feedbackPassageID: feedback.passageID))
      let badAnchor = EvidenceAnchor(
        sourceID: valid.feedbackEvidence.sourceID, passageID: valid.feedbackEvidence.passageID,
        quote: "bad", location: 1, length: 1)
      let invalid = ReviewFinding(
        category: .improve, explanation: "x", nextStep: "x", workEvidence: valid.workEvidence,
        feedbackEvidence: badAnchor)
      let ticket = try store.beginGeneration(for: request)
      let output = MentorOutput(
        summary: "Review", recommendations: [],
        evidenceSourceIDs: [valid.workEvidence.sourceID, valid.feedbackEvidence.sourceID],
        findings: [invalid])
      XCTAssertThrowsError(try store.saveReport(request: request, output: output, ticket: ticket))
    }
  }

  func testJointPairRequiredEvenForInsufficientEvidence() async throws {
    try await MainActor.run {
      let store = UniCoachStore(
        fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
      let subject = Subject(name: "S")
      try store.upsertSubject(subject)
      let a = Assignment(
        subjectID: subject.id, tutorFeedback: "Feedback A", submittedWork: "Work A")
      let b = Assignment(
        subjectID: subject.id, tutorFeedback: "Feedback B", submittedWork: "Work B")
      try store.upsertAssignment(a)
      try store.upsertAssignment(b)
      let all = store.contextSources()
      let aw = try XCTUnwrap(all.first { $0.id == "assignment:\(a.id.uuidString):work" })
      let af = try XCTUnwrap(all.first { $0.id == "assignment:\(a.id.uuidString):feedback" })
      let bf = try XCTUnwrap(all.first { $0.id == "assignment:\(b.id.uuidString):feedback" })
      @MainActor func attempt(_ sources: [ContextSource]) throws -> MentorReport {
        var draft = ConsentDraft(assignmentID: a.id)
        sources.forEach { draft.setSelected(true, source: $0) }
        let request = try store.approve(draft: draft)
        let ticket = try store.beginGeneration(for: request)
        return try store.saveReport(
          request: request,
          output: .init(
            summary: "Insufficient evidence", recommendations: [], evidenceSourceIDs: [],
            findings: []), ticket: ticket)
      }
      XCTAssertThrowsError(try attempt([aw]))
      XCTAssertThrowsError(try attempt([af]))
      XCTAssertThrowsError(try attempt([aw, bf]))
      XCTAssertEqual(try attempt([aw, af]).output.findings, [])
    }
  }

  func testFocusPersistenceSampleAndProgressAreExplicit() async throws {
    try await MainActor.run {
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      let store = UniCoachStore(fileURL: url)
      let subject = try store.addSampleSubject()
      let assignment = try XCTUnwrap(store.data.assignments.first { $0.subjectID == subject.id })
      var draft = ConsentDraft(assignmentID: assignment.id)
      XCTAssertTrue(draft.selectedSources.isEmpty)
      for source in store.contextSources(assignmentID: assignment.id)
      where source.id.hasSuffix(":work") || source.id.hasSuffix(":feedback") {
        draft.setSelected(true, source: source)
      }
      let request = try store.approve(draft: draft)
      let ticket = try store.beginGeneration(for: request)
      let output = try store.generateOffline(request: request)
      XCTAssertEqual(output.findings, [])
      let report = try store.saveReport(request: request, output: output, ticket: ticket)
      let focus = try store.createFocus(title: "Explain evidence", reportID: report.id)
      XCTAssertTrue(focus.isDemo)
      XCTAssertNil(focus.findingIndex)
      try store.updateFocusStatus(id: focus.id, status: .improved)
      let repeated = try store.createFocus(title: "  Explain evidence  ", reportID: report.id)
      XCTAssertEqual(repeated.id, focus.id)
      XCTAssertEqual(repeated.status, .improved)
      XCTAssertEqual(store.data.focusActions.count, 1)
      let progress = try XCTUnwrap(store.contextSources().first { $0.id == "progress" })
      XCTAssertTrue(progress.text.contains("Focus improved: 0"))
      try store.deleteSubject(id: subject.id)
      let loaded = UniCoachStore(fileURL: url).data
      XCTAssertEqual(loaded.focusActions.first?.status, .improved)
      XCTAssertEqual(loaded.focusActions.first?.isDemo, true)
      XCTAssertEqual(loaded.reports.first, report)
    }
  }
}

extension JointReviewTests {
  func testRedactedJointFindingCanBeAdoptedAndPersists() async throws {
    try await MainActor.run {
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      let store = UniCoachStore(fileURL: url)
      let subject = Subject(name: "S")
      try store.upsertSubject(subject)
      let assignment = Assignment(
        subjectID: subject.id, tutorFeedback: "😀 Explain the example. Secret.",
        reflection: "private reflection", submittedWork: "Example text secret")
      try store.upsertAssignment(assignment)
      var draft = ConsentDraft(assignmentID: assignment.id)
      XCTAssertTrue(draft.selectedSources.isEmpty)
      let work = try XCTUnwrap(store.contextSources().first { $0.id.hasSuffix(":work") })
      let feedback = try XCTUnwrap(store.contextSources().first { $0.id.hasSuffix(":feedback") })
      draft.setSelected(true, source: work)
      draft.setSelected(true, source: feedback)
      draft.setText("Example [redacted]", sourceID: work.id)
      draft.setText("😀 Explain the example.", sourceID: feedback.id)
      let request = try store.approve(draft: draft)
      let passages = store.evidencePassages(request: request)
      XCTAssertFalse(passages.map(\.quote).joined().contains("secret"))
      XCTAssertFalse(passages.map(\.quote).joined().contains("private reflection"))
      let w = try XCTUnwrap(passages.first { $0.sourceID == work.id })
      let f = try XCTUnwrap(passages.first { $0.sourceID == feedback.id })
      let finding = try store.resolveFinding(
        request: request, category: .improve, explanation: "Explain the example",
        nextStep: "Add a link", workPassageID: w.passageID, feedbackPassageID: f.passageID)
      let output = MentorOutput(
        summary: "Review", recommendations: [], evidenceSourceIDs: [w.sourceID, f.sourceID],
        findings: [finding])
      let ticket = try store.beginGeneration(for: request)
      let report = try store.saveReport(
        request: request, output: output, ticket: ticket, instructionsSnapshot: "instruction",
        promptSnapshots: ["joint approved prompt"])
      let action = try store.adoptFocus(reportID: report.id, findingIndex: 0, title: "Add a link")
      XCTAssertEqual(action.findingIndex, 0)
      XCTAssertFalse(action.isDemo)
      try store.updateFocusStatus(id: action.id, status: .awaitingFeedback)
      let repeated = try store.adoptFocus(
        reportID: report.id, findingIndex: 0, title: "Different title")
      XCTAssertEqual(repeated.id, action.id)
      XCTAssertEqual(repeated.status, .awaitingFeedback)
      XCTAssertEqual(store.data.focusActions.count, 1)
      let reloaded = UniCoachStore(fileURL: url)
      XCTAssertEqual(reloaded.data.reports.first?.output.findings, [finding])
      XCTAssertEqual(reloaded.data.reports.first?.promptSnapshots, ["joint approved prompt"])
      XCTAssertEqual(reloaded.data.focusActions.first?.status, .awaitingFeedback)
      XCTAssertTrue(
        try XCTUnwrap(reloaded.contextSources().first { $0.id == "progress" }).text.contains(
          "Focus awaiting feedback: 1"))
      try store.deleteReport(id: report.id)
      try store.deleteAssignment(id: assignment.id)
      XCTAssertEqual(store.data.focusActions.first?.title, "Add a link")
    }
  }
}
