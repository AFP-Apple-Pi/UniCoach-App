import Foundation
import Observation

@MainActor @Observable public final class UniCoachStore {
  public private(set) var data: AppData
  public private(set) var loadingError: String?
  public let fileURL: URL
  private var activeTickets: Set<GenerationTicket> = []
  private var approvedRequests: [UUID: ApprovedRequest] = [:]
  private var startedRequests: Set<UUID> = []
  private var sourceRevisions: [String: UInt64] = [:]
  private var assignmentRevisions: [UUID: UInt64] = [:]
  public static let contextCharacterLimit = 6000

  public init(fileURL: URL? = nil) {
    self.fileURL =
      fileURL
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("UniCoach/data.json")
    self.data = AppData()
    do {
      if FileManager.default.fileExists(atPath: self.fileURL.path) {
        self.data = try JSONDecoder().decode(AppData.self, from: Data(contentsOf: self.fileURL))
      }
    } catch { self.loadingError = "Could not load saved data: \(error.localizedDescription)" }
  }
  private func commit(_ next: AppData) throws {
    // Never overwrite an unreadable existing file until the user has recovered it.
    if loadingError != nil { throw CocoaError(.fileReadCorruptFile) }
    let encoded = try JSONEncoder().encode(next)
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try encoded.write(to: fileURL, options: .atomic)
    let before = Dictionary(uniqueKeysWithValues: contextSources().map { ($0.id, $0.fingerprint) })
    let oldAssignments = Dictionary(uniqueKeysWithValues: data.assignments.map { ($0.id, $0) })
    let newAssignments = Dictionary(uniqueKeysWithValues: next.assignments.map { ($0.id, $0) })
    for id in Set(oldAssignments.keys).union(newAssignments.keys)
    where oldAssignments[id] != newAssignments[id] { assignmentRevisions[id, default: 0] &+= 1 }
    data = next
    let after = Dictionary(uniqueKeysWithValues: contextSources().map { ($0.id, $0.fingerprint) })
    for id in Set(before.keys).union(after.keys) where before[id] != after[id] {
      sourceRevisions[id, default: 0] &+= 1
    }
  }
  public func saveProfile(_ profile: AcademicProfile) throws {
    var n = data
    var normalized = profile
    let text = normalized.learningGoal
    normalized.learningGoal = ""
    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !n.goals.contains(where: { $0.subjectID == nil && $0.title == text })
    {
      n.goals.append(LearningGoal(title: text))
    }
    n.profile = normalized
    try commit(n)
  }
  public func upsertSubject(_ subject: Subject) throws {
    var n = data
    var normalized = subject
    let text = normalized.academicGoal
    normalized.academicGoal = ""
    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !n.goals.contains(where: { $0.subjectID == subject.id && $0.title == text })
    {
      n.goals.append(LearningGoal(subjectID: subject.id, title: text, isDemo: subject.isDemo))
    }
    if let i = n.subjects.firstIndex(where: { $0.id == subject.id }) {
      n.subjects[i] = normalized
    } else {
      n.subjects.append(normalized)
    }
    try commit(n)
  }
  public func deleteSubject(id: UUID) throws {
    var n = data
    n.subjects.removeAll { $0.id == id }
    n.assignments.removeAll { $0.subjectID == id }
    n.goals.removeAll { $0.subjectID == id && $0.originAssignmentID == nil }
    try commit(n)
  }
  public func upsertAssignment(_ assignment: Assignment) throws {
    guard data.subjects.contains(where: { $0.id == assignment.subjectID }) else {
      throw UniCoachError.invalidRelationship
    }
    switch (assignment.score, assignment.outOf) {
    case (nil, nil): break
    case (nil, let maximum?) where maximum.isFinite && maximum > 0: break
    case (let score?, let maximum?)
    where score.isFinite && maximum.isFinite && maximum > 0 && score >= 0 && score <= maximum: break
    default: throw UniCoachError.invalidGrade
    }
    var n = data
    if let i = n.assignments.firstIndex(where: { $0.id == assignment.id }) {
      n.assignments[i] = assignment
    } else {
      n.assignments.append(assignment)
    }
    try commit(n)
  }
  public func deleteAssignment(id: UUID) throws {
    var n = data
    n.assignments.removeAll { $0.id == id }
    try commit(n)
  }
  public func upsertGoal(_ goal: LearningGoal) throws {
    if let id = goal.subjectID, !data.subjects.contains(where: { $0.id == id }) {
      guard let existing = data.goals.first(where: { $0.id == goal.id }), existing.subjectID == id
      else {
        throw UniCoachError.invalidRelationship
      }
    }
    var n = data
    var updated = goal
    if let i = n.goals.firstIndex(where: { $0.id == goal.id }) {
      if updated.isComplete != n.goals[i].isComplete {
        updated.completedAt = updated.isComplete ? Date() : nil
      }
      n.goals[i] = updated
    } else {
      if updated.isComplete && updated.completedAt == nil { updated.completedAt = Date() }
      n.goals.append(updated)
    }
    try commit(n)
  }
  public func deleteGoal(id: UUID) throws {
    var n = data
    n.goals.removeAll { $0.id == id }
    try commit(n)
  }
  public func deleteReport(id: UUID) throws {
    var n = data
    n.reports.removeAll { $0.id == id }
    try commit(n)
  }
  @discardableResult public func addSampleSubject() throws -> Subject {
    let subject = Subject(
      code: "DEMO101", name: "Example subject", credits: 6, tutor: "Example tutor", isDemo: true)
    var n = data
    n.subjects.append(subject)
    n.goals.append(
      LearningGoal(subjectID: subject.id, title: "Practise planning an assignment", isDemo: true))
    n.assignments.append(
      Assignment(
        subjectID: subject.id, title: "Example assignment",
        brief: "Plan a short evidence-based response.",
        dueDate: Date().addingTimeInterval(7 * 86400),
        tutorFeedback:
          "Your example is clear. You should explain how the evidence supports your claim.",
        reflection: "I want to make my reasoning easier to follow.",
        isDemo: true,
        submittedWork:
          "Community gardens can improve wellbeing. One study found participants met neighbours more often."
      ))
    try commit(n)
    return subject
  }
  public func subjectMarks(subjectID: UUID, includeDemo: Bool = false) -> MarkSummary {
    let graded = data.assignments.filter {
      $0.subjectID == subjectID && (includeDemo || !$0.isDemo) && $0.score != nil && $0.outOf != nil
    }
    return MarkSummary(
      score: graded.compactMap(\.score).reduce(0, +),
      outOf: graded.compactMap(\.outOf).reduce(0, +), gradedCount: graded.count)
  }

  public func gradedAssignments(subjectID: UUID, includeDemo: Bool = false) -> [Assignment] {
    data.assignments.filter {
      $0.subjectID == subjectID && (includeDemo || !$0.isDemo) && $0.score != nil && $0.outOf != nil
    }.sorted { lhs, rhs in
      switch (lhs.chartDate, rhs.chartDate) {
      case (let left?, let right?):
        return left == right ? lhs.id.uuidString < rhs.id.uuidString : left < right
      case (_?, nil): return true
      case (nil, _?): return false
      case (nil, nil): return lhs.id.uuidString < rhs.id.uuidString
      }
    }
  }

  @discardableResult public func createGoalFromReport(reportID: UUID) throws -> LearningGoal {
    if let existing = data.goals.first(where: {
      $0.sourceReportID == reportID && $0.isAdviceGoal
    }) {
      return existing
    }
    guard let report = data.reports.first(where: { $0.id == reportID }),
      let assignmentID = report.assignmentID,
      let assignment = data.assignments.first(where: { $0.id == assignmentID }),
      let title = report.output.advice?.nextStep.trimmingCharacters(in: .whitespacesAndNewlines),
      !title.isEmpty
    else { throw UniCoachError.invalidRelationship }
    let goal = LearningGoal(
      subjectID: assignment.subjectID, title: title, sourceReportID: reportID,
      originAssignmentID: assignmentID, isDemo: assignment.isDemo, isAdviceGoal: true)
    var next = data
    next.goals.append(goal)
    try commit(next)
    return goal
  }

  public func contextSources(assignmentID: UUID? = nil) -> [ContextSource] {
    var sources: [ContextSource] = []
    func add(_ id: String, _ title: String, _ text: String, _ record: String) {
      if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        sources.append(
          ContextSource(
            id: id, title: title, text: text,
            fingerprint: fingerprint(record) + ":" + String(sourceRevisions[id, default: 0])))
      }
    }
    let realSubjects = data.subjects.filter { !$0.isDemo }
    let realSubjectIDs = Set(realSubjects.map(\.id))
    let realAssignments = data.assignments.filter {
      !$0.isDemo && realSubjectIDs.contains($0.subjectID)
    }
    let realAssignmentIDs = Set(realAssignments.map(\.id))
    let realGoals = data.goals.filter {
      !$0.isDemo && ($0.subjectID == nil || realSubjectIDs.contains($0.subjectID!))
    }
    let realFocus = data.focusActions.filter {
      !$0.isDemo && realAssignmentIDs.contains($0.assignmentID)
        && realSubjectIDs.contains($0.subjectID)
    }
    let gradeSummary = "Grades available per subject"
    let progress = [
      "Subjects: \(realSubjects.count)", "Assignments: \(realAssignments.count)", gradeSummary,
      "Goals completed: \(realGoals.filter(\.isCompleted).count) of \(realGoals.count)",
      "Focus working on it: \(realFocus.filter { $0.status == .workingOnIt }.count)",
      "Focus improved: \(realFocus.filter { $0.status == .improved }.count)",
      "Focus awaiting feedback: \(realFocus.filter { $0.status == .awaitingFeedback }.count)",
    ].joined(separator: "\n")
    let progressRecord =
      record(realSubjects) + record(realAssignments) + record(realGoals) + record(realFocus)
    add("progress", "Progress overview", progress, progressRecord)
    let p = data.profile
    add(
      "profile", "Academic profile",
      [
        p.name.isEmpty ? "" : "Name: \(p.name)",
        p.university.isEmpty ? "" : "University: \(p.university)",
        p.course.isEmpty ? "" : "Course: \(p.course)",
      ].filter { !$0.isEmpty }.joined(separator: "\n"), record(p))
    let selected = assignmentID.flatMap { id in data.assignments.first { $0.id == id } }
    let subjects =
      selected.map { a in data.subjects.filter { $0.id == a.subjectID } }
      ?? (assignmentID == nil ? data.subjects : [])
    for s in subjects {
      add(
        "subject:\(s.id.uuidString)", "Subject overview",
        [
          "Code: \(s.code)", "Subject: \(s.name)", "Credits: \(s.credits)", "Tutor: \(s.tutor)",
        ].joined(separator: "\n"), record(s))
    }
    let assignments = selected.map { [$0] } ?? (assignmentID == nil ? data.assignments : [])
    for a in assignments {
      add("assignment:\(a.id.uuidString):work", "Submitted work", a.submittedWork, record(a))
      add("assignment:\(a.id.uuidString):brief", "Assignment brief", a.brief, record(a))
      add("assignment:\(a.id.uuidString):feedback", "Tutor feedback", a.tutorFeedback, record(a))
      add("assignment:\(a.id.uuidString):reflection", "Reflection", a.reflection, record(a))
    }
    for g in data.goals
    where selected == nil || g.subjectID == nil || g.subjectID == selected?.subjectID {
      add(
        "goal:\(g.id.uuidString)", "Learning goal",
        "\(g.title) (\(g.isCompleted ? "completed" : "in progress"))", record(g))
    }
    return sources
  }
  public func approve(draft: ConsentDraft, assignmentID: UUID? = nil) throws -> ApprovedRequest {
    let q = draft.question.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !draft.selectedSources.isEmpty else { throw UniCoachError.noSources }
    guard
      draft.selectedSources.allSatisfy({
        !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      })
    else { throw UniCoachError.emptySource }
    guard
      q.count + draft.selectedSources.reduce(0, { $0 + $1.text.count })
        <= Self.contextCharacterLimit
    else { throw UniCoachError.contextTooLong }
    let current = Dictionary(uniqueKeysWithValues: contextSources().map { ($0.id, $0.fingerprint) })
    let approved = try draft.selectedSources.map { source -> ApprovedSource in
      guard let original = draft.originals[source.id], current[source.id] == original else {
        throw UniCoachError.sourceChanged
      }
      return ApprovedSource(
        id: source.id, title: source.title, text: source.text, originalFingerprint: original)
    }
    let anchor = assignmentID ?? draft.assignmentID
    let anchorFingerprint: String?
    if let anchor {
      guard let assignment = data.assignments.first(where: { $0.id == anchor }) else {
        throw UniCoachError.sourceChanged
      }
      anchorFingerprint =
        fingerprint(record(assignment)) + ":" + String(assignmentRevisions[anchor, default: 0])
    } else {
      anchorFingerprint = nil
    }
    let request = ApprovedRequest(
      question: q, engine: draft.engine, sources: approved, assignmentID: anchor,
      assignmentFingerprint: anchorFingerprint)
    approvedRequests[request.id] = request
    return request
  }
  private func validateCurrent(_ request: ApprovedRequest) throws {
    if let id = request.assignmentID {
      guard let assignment = data.assignments.first(where: { $0.id == id }),
        request.assignmentFingerprint == fingerprint(record(assignment)) + ":"
          + String(assignmentRevisions[id, default: 0])
      else { throw UniCoachError.sourceChanged }
    }
    let current = Dictionary(uniqueKeysWithValues: contextSources().map { ($0.id, $0.fingerprint) })
    guard !request.sources.isEmpty,
      request.sources.allSatisfy({ source in
        current[source.id].map { $0 == source.originalFingerprint } ?? false
      })
    else { throw UniCoachError.sourceChanged }
  }
  /// Passage offsets and lengths use UTF-16, matching NSRange and text selection APIs.
  /// All approved work and feedback text is represented, without truncation.
  public func evidencePassages(request: ApprovedRequest) -> [EvidencePassage] {
    guard let assignmentID = request.assignmentID else { return [] }
    let prefix = "assignment:\(assignmentID.uuidString):"
    let permitted = Set([prefix + "work", prefix + "feedback"])
    var passages: [EvidencePassage] = []
    for source in request.sources where permitted.contains(source.id) {
      var start = source.text.startIndex
      while start < source.text.endIndex {
        let limit =
          source.text.index(start, offsetBy: 240, limitedBy: source.text.endIndex)
          ?? source.text.endIndex
        var end = limit
        if limit < source.text.endIndex {
          var cursor = start
          var lastWhitespace: String.Index?
          var lastSentence: String.Index?
          var previous: Character?
          while cursor < limit {
            let character = source.text[cursor]
            let next = source.text.index(after: cursor)
            if character.isWhitespace {
              lastWhitespace = next
              if character.isNewline || previous == "." || previous == "!" || previous == "?" {
                lastSentence = next
              }
            }
            previous = character
            cursor = next
          }
          let minimum = source.text.index(start, offsetBy: 80, limitedBy: limit) ?? start
          if let sentence = lastSentence, sentence >= minimum {
            end = sentence
          } else if let whitespace = lastWhitespace, whitespace > start {
            end = whitespace
          }
        }
        let range = start..<end
        let nsRange = NSRange(range, in: source.text)
        let id = "\(source.id):\(nsRange.location):\(nsRange.length)"
        passages.append(
          EvidencePassage(
            sourceID: source.id, passageID: id, quote: String(source.text[range]),
            location: nsRange.location, length: nsRange.length))
        start = end
      }
    }
    return passages
  }

  public func resolveFinding(
    request: ApprovedRequest, category: ReviewCategory, explanation: String, nextStep: String,
    workPassageID: String, feedbackPassageID: String
  ) throws -> ReviewFinding {
    guard let assignmentID = request.assignmentID,
      !explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !nextStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { throw UniCoachError.invalidEvidence }
    let passages = evidencePassages(request: request) + feedbackSentencePassages(request: request)
    let prefix = "assignment:\(assignmentID.uuidString):"
    guard
      let work = passages.first(where: {
        $0.passageID == workPassageID && $0.sourceID == prefix + "work"
      }),
      let feedback = passages.first(where: {
        $0.passageID == feedbackPassageID && $0.sourceID == prefix + "feedback"
      })
    else { throw UniCoachError.invalidEvidence }
    func anchor(_ passage: EvidencePassage) -> EvidenceAnchor {
      EvidenceAnchor(
        sourceID: passage.sourceID, passageID: passage.passageID, quote: passage.quote,
        location: passage.location, length: passage.length)
    }
    return ReviewFinding(
      category: category, explanation: explanation, nextStep: nextStep, workEvidence: anchor(work),
      feedbackEvidence: anchor(feedback))
  }

  private func validateFindings(
    _ findings: [ReviewFinding], request: ApprovedRequest, citedIDs: Set<String>
  ) throws {
    for finding in findings {
      let resolved = try resolveFinding(
        request: request, category: finding.category, explanation: finding.explanation,
        nextStep: finding.nextStep, workPassageID: finding.workEvidence.passageID,
        feedbackPassageID: finding.feedbackEvidence.passageID)
      guard resolved == finding, citedIDs.contains(finding.workEvidence.sourceID),
        citedIDs.contains(finding.feedbackEvidence.sourceID)
      else { throw UniCoachError.invalidEvidence }
      for anchor in [finding.workEvidence, finding.feedbackEvidence] {
        guard let source = request.sources.first(where: { $0.id == anchor.sourceID }),
          anchor.location >= 0, anchor.length > 0,
          let range = Range(
            NSRange(location: anchor.location, length: anchor.length), in: source.text),
          String(source.text[range]) == anchor.quote
        else { throw UniCoachError.invalidEvidence }
      }
    }
  }

  @discardableResult public func adoptFocus(reportID: UUID, findingIndex: Int, title: String) throws
    -> FocusAction
  {
    let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanTitle.isEmpty else { throw UniCoachError.invalidRelationship }
    if let existing = data.focusActions.first(where: {
      $0.reportID == reportID && $0.findingIndex == findingIndex
    }) {
      return existing
    }
    guard let report = data.reports.first(where: { $0.id == reportID }),
      let findings = report.output.findings, findings.indices.contains(findingIndex),
      let assignmentID = report.assignmentID,
      let assignment = data.assignments.first(where: { $0.id == assignmentID })
    else { throw UniCoachError.invalidRelationship }
    let now = Date()
    let action = FocusAction(
      reportID: reportID, assignmentID: assignmentID, subjectID: assignment.subjectID,
      title: cleanTitle, createdAt: now, updatedAt: now, findingIndex: findingIndex,
      isDemo: assignment.isDemo)
    var next = data
    next.goals.append(
      LearningGoal(
        id: action.id, subjectID: action.subjectID, title: action.title,
        sourceReportID: action.reportID, createdAt: action.createdAt,
        originAssignmentID: action.assignmentID, legacyFocusStatus: action.status,
        findingIndex: action.findingIndex, isDemo: action.isDemo, focusUpdatedAt: action.updatedAt))
    try commit(next)
    return action
  }

  /// Creates a focus entered by the user, without claiming an evidence-linked finding.
  @discardableResult public func createFocus(title: String, reportID: UUID) throws -> FocusAction {
    let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanTitle.isEmpty else { throw UniCoachError.invalidRelationship }
    if let existing = data.focusActions.first(where: {
      $0.reportID == reportID && $0.findingIndex == nil && $0.title == cleanTitle
    }) {
      return existing
    }
    guard let report = data.reports.first(where: { $0.id == reportID }),
      let assignmentID = report.assignmentID,
      let assignment = data.assignments.first(where: { $0.id == assignmentID })
    else { throw UniCoachError.invalidRelationship }
    let now = Date()
    let action = FocusAction(
      reportID: reportID, assignmentID: assignmentID, subjectID: assignment.subjectID,
      title: cleanTitle, createdAt: now, updatedAt: now, isDemo: assignment.isDemo)
    var next = data
    next.goals.append(
      LearningGoal(
        id: action.id, subjectID: action.subjectID, title: action.title,
        sourceReportID: action.reportID, createdAt: action.createdAt,
        originAssignmentID: action.assignmentID, legacyFocusStatus: action.status,
        findingIndex: action.findingIndex, isDemo: action.isDemo, focusUpdatedAt: action.updatedAt))
    try commit(next)
    return action
  }

  public func updateFocusStatus(id: UUID, status: FocusStatus) throws {
    var next = data
    guard let index = next.goals.firstIndex(where: { $0.id == id && $0.legacyFocusStatus != nil })
    else {
      throw UniCoachError.invalidRelationship
    }
    next.goals[index].legacyFocusStatus = status
    next.goals[index].focusUpdatedAt = Date()
    try commit(next)
  }

  public func deleteFocus(id: UUID) throws {
    var next = data
    next.goals.removeAll { $0.id == id && $0.legacyFocusStatus != nil }
    try commit(next)
  }

  /// Exact sentences from the approved tutor feedback for the anchored assignment.
  public func feedbackSentences(request: ApprovedRequest) -> [String] {
    feedbackSentencePassages(request: request).map(\.quote)
  }

  /// Sentence IDs resolve locally to exact approved text, so a model need not copy quotes.
  public func feedbackSentencePassages(request: ApprovedRequest) -> [EvidencePassage] {
    guard let id = request.assignmentID,
      let feedback = request.sources.first(where: {
        $0.id == "assignment:\(id.uuidString):feedback"
      })
    else { return [] }
    let text = feedback.text
    return sentenceRanges(in: text).map { range in
      let nsRange = NSRange(range, in: text)
      return EvidencePassage(
        sourceID: feedback.id,
        passageID: "\(feedback.id):sentence:\(nsRange.location):\(nsRange.length)",
        quote: String(text[range]), location: nsRange.location, length: nsRange.length)
    }
  }

  private func validateAdvice(
    _ advice: CoachingAdvice, request: ApprovedRequest, citedIDs: Set<String>
  ) throws {
    guard let id = request.assignmentID else { throw UniCoachError.invalidEvidence }
    let sentences = Set(feedbackSentences(request: request))
    let items = advice.keepDoing + advice.improve
    guard advice.keepDoing.count <= 3, advice.improve.count <= 3,
      items.allSatisfy({
        !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          && sentences.contains($0.tutorQuote)
      }),
      advice.improve.isEmpty
        ? advice.nextStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        : !advice.nextStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      items.isEmpty || citedIDs.contains("assignment:\(id.uuidString):feedback")
    else { throw UniCoachError.invalidEvidence }
  }

  public func beginGeneration(for request: ApprovedRequest) throws -> GenerationTicket {
    guard approvedRequests[request.id] == request, !startedRequests.contains(request.id) else {
      throw UniCoachError.cancelled
    }
    try validateCurrent(request)
    startedRequests.insert(request.id)
    let ticket = GenerationTicket(requestID: request.id)
    activeTickets.insert(ticket)
    return ticket
  }
  public func cancel(ticket: GenerationTicket) {
    if activeTickets.remove(ticket) != nil {
      approvedRequests.removeValue(forKey: ticket.requestID)
      startedRequests.remove(ticket.requestID)
    }
  }
  public func generateOffline(request: ApprovedRequest) throws -> MentorOutput {
    guard request.engine == .contextualOffline else { throw UniCoachError.engineUnavailable }
    guard !request.sources.isEmpty else { throw UniCoachError.noSources }
    let passages = evidencePassages(request: request)
    let hasWork = passages.contains { $0.sourceID.hasSuffix(":work") }
    let hasFeedback = passages.contains { $0.sourceID.hasSuffix(":feedback") }
    if hasWork && hasFeedback {
      let excerpts = passages.map { passage in
        let label = passage.sourceID.hasSuffix(":work") ? "Submitted work" : "Tutor feedback"
        return "\(label): \(passage.quote)"
      }
      let sentences = feedbackSentences(request: request)
      func includesWord(_ sentence: String, keywords: Set<String>) -> Bool {
        let words = sentence.lowercased().components(separatedBy: CharacterSet.letters.inverted)
        return words.contains { keywords.contains($0) }
      }
      let keep = sentences.filter {
        includesWord($0, keywords: ["strong", "good", "clear", "well"])
      }.prefix(3).map { AdviceItem(text: $0, tutorQuote: $0) }
      let improve = sentences.filter {
        includesWord($0, keywords: ["needs", "weak", "missing", "should", "unclear"])
      }.prefix(3).map { AdviceItem(text: $0, tutorQuote: $0) }
      let advice = CoachingAdvice(
        keepDoing: Array(keep), improve: Array(improve), nextStep: improve.first?.text ?? "")
      return MentorOutput(
        summary: "Keyword-based offline review (not AI). Excerpts are not automatically linked.",
        recommendations: excerpts, evidenceSourceIDs: request.sources.map(\.id), findings: [],
        advice: advice)
    }
    let reviews = request.sources.enumerated().map { index, source in
      "[S\(index + 1)] Review approved detail: \(String(source.text.prefix(180)))"
    }
    return MentorOutput(
      summary: "Contextual offline guidance (not AI)",
      recommendations: reviews + [
        "Turn each relevant detail into a specific next action and schedule time to complete it.",
        "Compare your work against the approved material before submitting.",
      ], evidenceSourceIDs: request.sources.map(\.id))
  }
  @discardableResult public func saveReport(
    request: ApprovedRequest, output: MentorOutput, ticket: GenerationTicket,
    instructionsSnapshot: String? = nil, promptSnapshots: [String] = []
  ) throws -> MentorReport {
    guard ticket.requestID == request.id, approvedRequests[request.id] == request,
      activeTickets.contains(ticket), !Task.isCancelled
    else {
      if activeTickets.remove(ticket) != nil {
        approvedRequests.removeValue(forKey: ticket.requestID)
        startedRequests.remove(ticket.requestID)
      }
      throw UniCoachError.cancelled
    }
    defer {
      activeTickets.remove(ticket)
      approvedRequests.removeValue(forKey: ticket.requestID)
      startedRequests.remove(ticket.requestID)
    }
    try validateCurrent(request)
    let allowed = Set(request.sources.map(\.id))
    let hasApprovedPair =
      request.assignmentID.map { id in
        allowed.contains("assignment:\(id.uuidString):work")
          && allowed.contains("assignment:\(id.uuidString):feedback")
      } == true
    let pairedInsufficient = output.findings?.isEmpty == true && hasApprovedPair
    guard !output.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !output.evidenceSourceIDs.isEmpty || pairedInsufficient,
      output.evidenceSourceIDs.allSatisfy({ allowed.contains($0) })
    else { throw UniCoachError.invalidEvidence }
    if let advice = output.advice {
      guard hasApprovedPair else { throw UniCoachError.invalidEvidence }
      try validateAdvice(advice, request: request, citedIDs: Set(output.evidenceSourceIDs))
    }
    if let findings = output.findings {
      guard hasApprovedPair else { throw UniCoachError.invalidEvidence }
      try validateFindings(findings, request: request, citedIDs: Set(output.evidenceSourceIDs))
    }
    let report = MentorReport(
      question: request.question, engine: request.engine, sources: request.sources, output: output,
      assignmentID: request.assignmentID, instructionsSnapshot: instructionsSnapshot,
      promptSnapshots: promptSnapshots)
    var n = data
    n.reports.insert(report, at: 0)
    try commit(n)
    return report
  }
}
private func fingerprint(_ text: String) -> String {
  var hash: UInt64 = 14_695_981_039_346_656_037
  for byte in text.utf8 { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
  return String(hash, radix: 16)
}

private func record<T: Encodable>(_ value: T) -> String {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  return (try? encoder.encode(value)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
}

/// Conservative sentence boundaries retain punctuation, decimals and common abbreviations.
private func sentenceRanges(in text: String) -> [Range<String.Index>] {
  var ranges: [Range<String.Index>] = []
  var start = text.startIndex
  var cursor = start
  let abbreviations: Set<String> = [
    "mr.", "mrs.", "ms.", "dr.", "prof.", "e.g.", "i.e.", "vs.", "etc.",
  ]
  func append(_ raw: Range<String.Index>) {
    let part = text[raw]
    guard let first = part.firstIndex(where: { !$0.isWhitespace }),
      let last = part.lastIndex(where: { !$0.isWhitespace })
    else { return }
    ranges.append(first..<text.index(after: last))
  }
  while cursor < text.endIndex {
    let character = text[cursor]
    let next = text.index(after: cursor)
    if character.isNewline {
      append(start..<cursor)
      start = next
      cursor = next
      continue
    }
    guard character == "." || character == "!" || character == "?" else {
      cursor = next
      continue
    }
    if character == ".", cursor > start, next < text.endIndex,
      text[text.index(before: cursor)].isNumber && text[next].isNumber
    {
      cursor = next
      continue
    }
    if character == ".", next < text.endIndex, text[next].isLetter {
      cursor = next
      continue
    }
    var end = next
    while end < text.endIndex && ".!?".contains(text[end]) { end = text.index(after: end) }
    let prefix = text[start..<end].lowercased()
    let token = prefix.split(whereSeparator: { $0.isWhitespace }).last.map(String.init) ?? ""
    if abbreviations.contains(token) && end < text.endIndex {
      cursor = end
      continue
    }
    append(start..<end)
    start = end
    cursor = end
  }
  append(start..<text.endIndex)
  return ranges
}
