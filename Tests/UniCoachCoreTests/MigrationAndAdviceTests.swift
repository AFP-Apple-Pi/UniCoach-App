import XCTest

@testable import UniCoachCore

final class MigrationAndAdviceTests: XCTestCase {
  func testFullLegacyMigrationIsNonDestructiveAndIdempotent() async throws {
    try await MainActor.run {
      let legacy = """
        {"profile":{"name":"Lee","university":"Uni","course":"Arts","learningGoal":"Degree goal","onboardingComplete":true},"subjects":[{"id":"11111111-1111-1111-1111-111111111111","code":"ART1","name":"Art","credits":6,"tutor":"Tutor","colorHex":"#123456","academicGoal":"Subject goal","isDemo":false}],"assignments":[{"id":"22222222-2222-2222-2222-222222222222","subjectID":"11111111-1111-1111-1111-111111111111","title":"Essay","brief":"Brief","dueDate":1000,"grade":72,"tutorFeedback":"Feedback","reflection":"Reflection","isDemo":false,"submittedWork":"Work"}],"goals":[{"id":"33333333-3333-3333-3333-333333333333","subjectID":"11111111-1111-1111-1111-111111111111","title":"Old goal","isCompleted":true}],"reports":[{"id":"44444444-4444-4444-4444-444444444444","createdAt":2000,"question":"Question","engine":"appleOnDevice","sources":[{"id":"profile","title":"Academic profile","text":"Approved","originalFingerprint":"abc"}],"output":{"summary":"Summary","recommendations":["Next"],"evidenceSourceIDs":["profile"]},"assignmentID":"22222222-2222-2222-2222-222222222222","instructionsSnapshot":"Instruction","promptSnapshots":["Prompt"]}],"focusActions":[{"id":"55555555-5555-5555-5555-555555555555","reportID":"44444444-4444-4444-4444-444444444444","assignmentID":"22222222-2222-2222-2222-222222222222","subjectID":"11111111-1111-1111-1111-111111111111","title":"Focus","status":"improved","createdAt":3000,"updatedAt":4000,"findingIndex":2,"isDemo":false}]}
        """
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      let bytes = Data(legacy.utf8)
      try bytes.write(to: url)
      let store = UniCoachStore(fileURL: url)
      XCTAssertNil(store.loadingError)
      XCTAssertEqual(try Data(contentsOf: url), bytes)
      XCTAssertEqual(store.data.schemaVersion, AppData.currentSchemaVersion)
      XCTAssertEqual(store.data.goals.count, 4)
      XCTAssertTrue(store.data.mentorAnswers.isEmpty)
      XCTAssertEqual(
        store.data.goals.first { $0.title == "Degree goal" }?.id.uuidString,
        "CCA262AE-4382-4D27-ACA2-62AE43828D27")
      XCTAssertEqual(
        store.data.goals.first { $0.title == "Subject goal" }?.id.uuidString,
        "0A7E3843-FA5B-4A1C-AA7E-3843FA5B3A1C")
      XCTAssertEqual(store.data.assignments.first?.score, 72)
      XCTAssertEqual(store.data.assignments.first?.outOf, 100)
      XCTAssertNil(store.data.assignments.first?.createdAt)
      let focus = try XCTUnwrap(store.data.goals.first { $0.title == "Focus" })
      XCTAssertFalse(focus.isComplete)
      XCTAssertNil(focus.completedAt)
      XCTAssertEqual(focus.legacyFocusStatus, .improved)
      XCTAssertEqual(focus.findingIndex, 2)
      XCTAssertEqual(focus.sourceReportID?.uuidString, "44444444-4444-4444-4444-444444444444")
      XCTAssertTrue(try XCTUnwrap(store.data.goals.first { $0.title == "Old goal" }).isComplete)
      XCTAssertNil(try XCTUnwrap(store.data.goals.first { $0.title == "Old goal" }).createdAt)
      XCTAssertEqual(store.data.reports.first?.promptSnapshots, ["Prompt"])
      let migrated = store.data
      try store.saveProfile(store.data.profile)
      let reload = UniCoachStore(fileURL: url)
      XCTAssertEqual(reload.data, migrated)
      try reload.saveProfile(reload.data.profile)
      XCTAssertEqual(UniCoachStore(fileURL: url).data, migrated)
    }
  }

  func testWeightedMarksDateFallbackAndValidation() async throws {
    try await MainActor.run {
      let store = UniCoachStore(
        fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
      let subject = Subject(name: "S", semester: "Sem 2, 2026")
      try store.upsertSubject(subject)
      let created = Date(timeIntervalSince1970: 100)
      try store.upsertAssignment(
        .init(subjectID: subject.id, dueDate: nil, score: 12.35, outOf: 20, createdAt: created))
      try store.upsertAssignment(.init(subjectID: subject.id, score: 35.8, outOf: 40))
      try store.upsertAssignment(.init(subjectID: subject.id, isDemo: true, score: 0, outOf: 100))
      let marks = store.subjectMarks(subjectID: subject.id)
      XCTAssertEqual(marks.score, 48.15, accuracy: 0.00001)
      XCTAssertEqual(marks.outOf, 60, accuracy: 0.00001)
      XCTAssertEqual(try XCTUnwrap(marks.percentage), 80.25, accuracy: 0.00001)
      XCTAssertEqual(store.data.assignments.first?.chartDate, created)
      XCTAssertThrowsError(
        try store.upsertAssignment(.init(subjectID: subject.id, score: 1, outOf: 0)))
      XCTAssertThrowsError(
        try store.upsertAssignment(.init(subjectID: subject.id, score: 21, outOf: 20)))
      XCTAssertThrowsError(try store.upsertAssignment(.init(subjectID: subject.id, score: 1)))
    }
  }

  func testOfflineKeywordSentenceQuotesAndGoalCreation() async throws {
    try await MainActor.run {
      let store = UniCoachStore(
        fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
      let subject = Subject(name: "S")
      try store.upsertSubject(subject)
      let assignment = Assignment(
        subjectID: subject.id,
        tutorFeedback:
          "Your answer is unclear. Your example is clear. You should add evidence. This is strong. This needs work.",
        submittedWork: "A draft")
      try store.upsertAssignment(assignment)
      var draft = ConsentDraft(assignmentID: assignment.id)
      for source in store.contextSources(assignmentID: assignment.id)
      where source.id.hasSuffix(":work") || source.id.hasSuffix(":feedback") {
        draft.setSelected(true, source: source)
      }
      let request = try store.approve(draft: draft)
      let ticket = try store.beginGeneration(for: request)
      let output = try store.generateOffline(request: request)
      let advice = try XCTUnwrap(output.advice)
      XCTAssertTrue(output.summary.contains("not AI"))
      XCTAssertEqual(
        advice.keepDoing.map(\.tutorQuote), ["Your example is clear.", "This is strong."])
      XCTAssertEqual(advice.improve.first?.tutorQuote, "Your answer is unclear.")
      XCTAssertEqual(advice.nextStep, "Your answer is unclear.")
      let report = try store.saveReport(request: request, output: output, ticket: ticket)
      let manual = LearningGoal(
        subjectID: subject.id, title: "Manual goal", sourceReportID: report.id)
      try store.upsertGoal(manual)
      let goal = try store.createGoalFromReport(reportID: report.id)
      XCTAssertNotEqual(goal.id, manual.id)
      XCTAssertEqual(goal.subjectID, subject.id)
      XCTAssertEqual(goal.sourceReportID, report.id)
      XCTAssertEqual(goal.title, advice.nextStep)
      XCTAssertNotNil(goal.createdAt)
      var completed = goal
      completed.isComplete = true
      try store.upsertGoal(completed)
      XCTAssertNotNil(store.data.goals.first { $0.id == goal.id }?.completedAt)
      let repeated = try store.createGoalFromReport(reportID: report.id)
      XCTAssertEqual(repeated.id, goal.id)
      XCTAssertTrue(repeated.isComplete)
      try store.deleteSubject(id: subject.id)
      var retained = try XCTUnwrap(store.data.goals.first { $0.id == goal.id })
      retained.title = "Updated after deletion"
      try store.upsertGoal(retained)
      XCTAssertEqual(
        UniCoachStore(fileURL: store.fileURL).data.goals.first { $0.id == goal.id }?.title,
        retained.title)
      XCTAssertThrowsError(try store.upsertGoal(LearningGoal(subjectID: UUID(), title: "Invalid")))
    }
  }

  func testInvalidAdviceQuoteAndExcessItemsAreRejected() async throws {
    try await MainActor.run {
      let store = UniCoachStore(
        fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
      let subject = Subject(name: "S")
      try store.upsertSubject(subject)
      let assignment = Assignment(
        subjectID: subject.id, tutorFeedback: "This is good.", submittedWork: "Draft")
      try store.upsertAssignment(assignment)
      var draft = ConsentDraft(assignmentID: assignment.id)
      for source in store.contextSources(assignmentID: assignment.id)
      where source.id.hasSuffix(":work") || source.id.hasSuffix(":feedback") {
        draft.setSelected(true, source: source)
      }
      @MainActor func attempt(_ advice: CoachingAdvice) throws {
        let request = try store.approve(draft: draft)
        let ticket = try store.beginGeneration(for: request)
        let output = MentorOutput(
          summary: "Review", recommendations: [], evidenceSourceIDs: request.sources.map(\.id),
          findings: [], advice: advice)
        try store.saveReport(request: request, output: output, ticket: ticket)
      }
      XCTAssertThrowsError(
        try attempt(
          .init(keepDoing: [.init(text: "Praise", tutorQuote: "good")], improve: [], nextStep: "")))
      XCTAssertThrowsError(
        try attempt(
          .init(
            keepDoing: Array(
              repeating: .init(text: "Praise", tutorQuote: "This is good."), count: 4), improve: [],
            nextStep: "")))
    }
  }
}

extension MigrationAndAdviceTests {
  func testGradeChartSortsDueDateThenCreationWithUnknownLastAndStableTies() async throws {
    try await MainActor.run {
      let store = UniCoachStore(
        fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
      let subject = Subject(name: "S")
      try store.upsertSubject(subject)
      let early = Date(timeIntervalSince1970: 100)
      let later = Date(timeIntervalSince1970: 200)
      let a = Assignment(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, subjectID: subject.id,
        dueDate: nil, score: 1, outOf: 2, createdAt: early)
      let b = Assignment(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, subjectID: subject.id,
        dueDate: early, score: 1, outOf: 2, createdAt: later)
      let c = Assignment(subjectID: subject.id, dueDate: nil, score: 1, outOf: 2, createdAt: nil)
      try store.upsertAssignment(c)
      try store.upsertAssignment(b)
      try store.upsertAssignment(a)
      XCTAssertEqual(store.gradedAssignments(subjectID: subject.id).map(\.id), [a.id, b.id, c.id])
    }
  }
  func testSentenceIDsResolveExactUnicodeWithoutModelQuoteCopying() async throws {
    try await MainActor.run {
      let store = UniCoachStore(
        fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
      let subject = Subject(name: "S")
      try store.upsertSubject(subject)
      let assignment = Assignment(
        subjectID: subject.id, tutorFeedback: "  😀 Good work.  You should add evidence!",
        submittedWork: "Evidence draft")
      try store.upsertAssignment(assignment)
      var draft = ConsentDraft(assignmentID: assignment.id)
      for source in store.contextSources(assignmentID: assignment.id)
      where source.id.hasSuffix(":work") || source.id.hasSuffix(":feedback") {
        draft.setSelected(true, source: source)
      }
      let request = try store.approve(draft: draft)
      let sentences = store.feedbackSentencePassages(request: request)
      XCTAssertEqual(sentences.map(\.quote), ["😀 Good work.", "You should add evidence!"])
      let work = try XCTUnwrap(
        store.evidencePassages(request: request).first { $0.sourceID.hasSuffix(":work") })
      let finding = try store.resolveFinding(
        request: request, category: .improve, explanation: "Evidence", nextStep: "Add evidence",
        workPassageID: work.passageID, feedbackPassageID: sentences[1].passageID)
      XCTAssertEqual(finding.feedbackEvidence.quote, "You should add evidence!")
      let feedback = try XCTUnwrap(request.sources.first { $0.id.hasSuffix(":feedback") })
      let range = try XCTUnwrap(
        Range(
          NSRange(location: sentences[1].location, length: sentences[1].length), in: feedback.text))
      XCTAssertEqual(String(feedback.text[range]), sentences[1].quote)
    }
  }
}

extension MigrationAndAdviceTests {
  func testFeedbackSentenceRangesKeepPunctuationDecimalsAndGaps() async throws {
    try await MainActor.run {
      let store = UniCoachStore(
        fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
      let subject = Subject(name: "S")
      try store.upsertSubject(subject)
      let text = "  Score 12.35/20. Dr. Lee said clear?!\n😀 Please improve...  "
      let assignment = Assignment(
        subjectID: subject.id, tutorFeedback: text, submittedWork: "Draft")
      try store.upsertAssignment(assignment)
      var draft = ConsentDraft(assignmentID: assignment.id)
      for source in store.contextSources(assignmentID: assignment.id)
      where source.id.hasSuffix(":feedback") { draft.setSelected(true, source: source) }
      let request = try store.approve(draft: draft)
      let sentences = store.feedbackSentencePassages(request: request)
      XCTAssertEqual(
        sentences.map(\.quote), ["Score 12.35/20.", "Dr. Lee said clear?!", "😀 Please improve..."])
      let original = text as NSString
      var cursor = 0
      var rebuilt = ""
      for sentence in sentences {
        rebuilt += original.substring(
          with: NSRange(location: cursor, length: sentence.location - cursor))
        rebuilt += sentence.quote
        cursor = sentence.location + sentence.length
      }
      rebuilt += original.substring(from: cursor)
      XCTAssertEqual(rebuilt, text)
    }
  }
}

extension MigrationAndAdviceTests {
  func testMaximumWithoutScorePersistsButIsNotGraded() async throws {
    try await MainActor.run {
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      let store = UniCoachStore(fileURL: url)
      let subject = Subject(name: "S")
      try store.upsertSubject(subject)
      let pending = Assignment(subjectID: subject.id, title: "Pending", outOf: 50)
      try store.upsertAssignment(pending)
      try store.upsertAssignment(Assignment(subjectID: subject.id, score: 12.35, outOf: 20))
      let reloaded = UniCoachStore(fileURL: url)
      let saved = try XCTUnwrap(reloaded.data.assignments.first { $0.id == pending.id })
      XCTAssertNil(saved.score)
      XCTAssertEqual(saved.outOf, 50)
      XCTAssertNil(saved.percentage)
      let marks = reloaded.subjectMarks(subjectID: subject.id)
      XCTAssertEqual(marks.score, 12.35, accuracy: 0.000001)
      XCTAssertEqual(marks.outOf, 20, accuracy: 0.000001)
      XCTAssertEqual(marks.gradedCount, 1)
      XCTAssertFalse(
        reloaded.gradedAssignments(subjectID: subject.id).contains { $0.id == pending.id })
      XCTAssertThrowsError(try store.upsertAssignment(Assignment(subjectID: subject.id, outOf: 0)))
      XCTAssertThrowsError(try store.upsertAssignment(Assignment(subjectID: subject.id, score: 1)))
    }
  }
}
