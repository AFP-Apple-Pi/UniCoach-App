import Foundation

public struct AcademicProfile: Codable, Equatable {
  public var name: String, university: String, course: String, learningGoal: String
  public var onboardingComplete: Bool
  public init(
    name: String = "", university: String = "", course: String = "", learningGoal: String = "",
    onboardingComplete: Bool = false
  ) {
    self.name = name
    self.university = university
    self.course = course
    self.learningGoal = learningGoal
    self.onboardingComplete = onboardingComplete
  }
}
public struct Subject: Codable, Identifiable, Equatable {
  public var id: UUID
  public var code: String, name: String
  public var credits: Double
  public var tutor: String, colorHex: String, academicGoal: String
  public var isDemo: Bool
  public init(
    id: UUID = UUID(), code: String = "", name: String = "", credits: Double = 0,
    tutor: String = "", colorHex: String = "#6750A4", academicGoal: String = "",
    isDemo: Bool = false
  ) {
    self.id = id
    self.code = code
    self.name = name
    self.credits = credits
    self.tutor = tutor
    self.colorHex = colorHex
    self.academicGoal = academicGoal
    self.isDemo = isDemo
  }
}
public struct Assignment: Codable, Identifiable, Equatable {
  public var id: UUID
  public var subjectID: UUID
  public var title: String, brief: String
  public var dueDate: Date
  public var grade: Double?
  public var tutorFeedback: String, reflection: String
  public var isDemo: Bool
  public var submittedWork: String
  public init(
    id: UUID = UUID(), subjectID: UUID, title: String = "", brief: String = "",
    dueDate: Date = Date(), grade: Double? = nil, tutorFeedback: String = "",
    reflection: String = "", isDemo: Bool = false, submittedWork: String = ""
  ) {
    self.id = id
    self.subjectID = subjectID
    self.title = title
    self.brief = brief
    self.dueDate = dueDate
    self.grade = grade
    self.tutorFeedback = tutorFeedback
    self.reflection = reflection
    self.isDemo = isDemo
    self.submittedWork = submittedWork
  }
  private enum CodingKeys: String, CodingKey {
    case id, subjectID, title, brief, dueDate, grade, tutorFeedback, reflection, isDemo,
      submittedWork
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    subjectID = try c.decode(UUID.self, forKey: .subjectID)
    title = try c.decode(String.self, forKey: .title)
    brief = try c.decode(String.self, forKey: .brief)
    dueDate = try c.decode(Date.self, forKey: .dueDate)
    grade = try c.decodeIfPresent(Double.self, forKey: .grade)
    tutorFeedback = try c.decode(String.self, forKey: .tutorFeedback)
    reflection = try c.decode(String.self, forKey: .reflection)
    isDemo = try c.decode(Bool.self, forKey: .isDemo)
    submittedWork = try c.decodeIfPresent(String.self, forKey: .submittedWork) ?? ""
  }
}
public struct LearningGoal: Codable, Identifiable, Equatable {
  public var id: UUID
  public var subjectID: UUID?
  public var title: String
  public var isCompleted: Bool
  public init(
    id: UUID = UUID(), subjectID: UUID? = nil, title: String = "", isCompleted: Bool = false
  ) {
    self.id = id
    self.subjectID = subjectID
    self.title = title
    self.isCompleted = isCompleted
  }
}
public enum MentorEngine: String, Codable, CaseIterable {
  case appleOnDevice, contextualOffline
  public var displayName: String {
    switch self {
    case .appleOnDevice: return "Apple on-device"
    case .contextualOffline: return "Contextual offline (not AI)"
    }
  }
}
public struct ContextSource: Identifiable, Equatable {
  public var id: String, title: String, text: String
  public let fingerprint: String
  public init(id: String, title: String, text: String, fingerprint: String = "") {
    self.id = id
    self.title = title
    self.text = text
    self.fingerprint = fingerprint
  }
}
public struct ApprovedSource: Codable, Identifiable, Equatable {
  public let id: String, title: String, text: String, originalFingerprint: String
  public init(id: String, title: String, text: String, originalFingerprint: String) {
    self.id = id
    self.title = title
    self.text = text
    self.originalFingerprint = originalFingerprint
  }
}
public struct ConsentDraft {
  public var question: String
  public var engine: MentorEngine
  public var assignmentID: UUID?
  public private(set) var selectedSources: [ContextSource]
  internal var originals: [String: String] = [:]
  public init(
    question: String = "", engine: MentorEngine = .contextualOffline, assignmentID: UUID? = nil
  ) {
    self.question = question
    self.engine = engine
    self.assignmentID = assignmentID
    self.selectedSources = []
  }
  public mutating func setSelected(_ selected: Bool, source: ContextSource) {
    if selected {
      if !selectedSources.contains(where: { $0.id == source.id }) {
        selectedSources.append(source)
        originals[source.id] = source.fingerprint
      }
    } else {
      selectedSources.removeAll { $0.id == source.id }
      originals.removeValue(forKey: source.id)
    }
  }
  public mutating func setText(_ text: String, sourceID: String) {
    if let i = selectedSources.firstIndex(where: { $0.id == sourceID }) {
      selectedSources[i].text = text
    }
  }
}
public struct ApprovedRequest: Codable, Identifiable, Equatable {
  public let id: UUID
  public let createdAt: Date
  public let question: String
  public let engine: MentorEngine
  public let sources: [ApprovedSource]
  public let assignmentID: UUID?
  internal let assignmentFingerprint: String?
  public init(
    id: UUID = UUID(), createdAt: Date = Date(), question: String, engine: MentorEngine,
    sources: [ApprovedSource], assignmentID: UUID? = nil, assignmentFingerprint: String? = nil
  ) {
    self.id = id
    self.createdAt = createdAt
    self.question = question
    self.engine = engine
    self.sources = sources
    self.assignmentID = assignmentID
    self.assignmentFingerprint = assignmentFingerprint
  }
}
public enum ReviewCategory: String, Codable, CaseIterable { case keepDoing, improve }
public struct EvidencePassage: Identifiable, Equatable {
  public let sourceID: String, passageID: String, quote: String
  public let location: Int, length: Int
  public var id: String { passageID }
  public init(sourceID: String, passageID: String, quote: String, location: Int, length: Int) {
    self.sourceID = sourceID
    self.passageID = passageID
    self.quote = quote
    self.location = location
    self.length = length
  }
}
public struct EvidenceAnchor: Codable, Equatable {
  public let sourceID: String, passageID: String, quote: String
  public let location: Int, length: Int
  public init(sourceID: String, passageID: String, quote: String, location: Int, length: Int) {
    self.sourceID = sourceID
    self.passageID = passageID
    self.quote = quote
    self.location = location
    self.length = length
  }
}
public struct ReviewFinding: Codable, Equatable {
  public let category: ReviewCategory
  public let explanation: String, nextStep: String
  public let workEvidence: EvidenceAnchor, feedbackEvidence: EvidenceAnchor
  public init(
    category: ReviewCategory, explanation: String, nextStep: String, workEvidence: EvidenceAnchor,
    feedbackEvidence: EvidenceAnchor
  ) {
    self.category = category
    self.explanation = explanation
    self.nextStep = nextStep
    self.workEvidence = workEvidence
    self.feedbackEvidence = feedbackEvidence
  }
}
public enum FocusStatus: String, Codable, CaseIterable {
  case workingOnIt, improved, awaitingFeedback
}
public struct FocusAction: Codable, Identifiable, Equatable {
  public let id: UUID, reportID: UUID, assignmentID: UUID, subjectID: UUID
  public let title: String
  public var status: FocusStatus
  public let createdAt: Date
  public var updatedAt: Date
  public let findingIndex: Int?
  public let isDemo: Bool
  public init(
    id: UUID = UUID(), reportID: UUID, assignmentID: UUID, subjectID: UUID, title: String,
    status: FocusStatus = .workingOnIt, createdAt: Date = Date(), updatedAt: Date = Date(),
    findingIndex: Int? = nil, isDemo: Bool = false
  ) {
    self.id = id
    self.reportID = reportID
    self.assignmentID = assignmentID
    self.subjectID = subjectID
    self.title = title
    self.status = status
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.findingIndex = findingIndex
    self.isDemo = isDemo
  }
  private enum CodingKeys: String, CodingKey {
    case id, reportID, assignmentID, subjectID, title, status, createdAt, updatedAt, findingIndex,
      isDemo
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    reportID = try c.decode(UUID.self, forKey: .reportID)
    assignmentID = try c.decode(UUID.self, forKey: .assignmentID)
    subjectID = try c.decode(UUID.self, forKey: .subjectID)
    title = try c.decode(String.self, forKey: .title)
    status = try c.decode(FocusStatus.self, forKey: .status)
    createdAt = try c.decode(Date.self, forKey: .createdAt)
    updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    findingIndex = try c.decodeIfPresent(Int.self, forKey: .findingIndex)
    isDemo = try c.decodeIfPresent(Bool.self, forKey: .isDemo) ?? false
  }
}
public struct MentorOutput: Codable, Equatable {
  public var summary: String
  public var recommendations: [String]
  public var evidenceSourceIDs: [String]
  public var findings: [ReviewFinding]?
  public init(
    summary: String, recommendations: [String], evidenceSourceIDs: [String],
    findings: [ReviewFinding]? = nil
  ) {
    self.summary = summary
    self.recommendations = recommendations
    self.evidenceSourceIDs = evidenceSourceIDs
    self.findings = findings
  }
}
public struct MentorReport: Codable, Identifiable, Equatable {
  public let id: UUID
  public let createdAt: Date
  public let question: String
  public let engine: MentorEngine
  public let sources: [ApprovedSource]
  public let output: MentorOutput
  public let assignmentID: UUID?
  public let instructionsSnapshot: String?
  public let promptSnapshots: [String]
  public init(
    id: UUID = UUID(), createdAt: Date = Date(), question: String, engine: MentorEngine,
    sources: [ApprovedSource], output: MentorOutput, assignmentID: UUID? = nil,
    instructionsSnapshot: String? = nil, promptSnapshots: [String] = []
  ) {
    self.id = id
    self.createdAt = createdAt
    self.question = question
    self.engine = engine
    self.sources = sources
    self.output = output
    self.assignmentID = assignmentID
    self.instructionsSnapshot = instructionsSnapshot
    self.promptSnapshots = promptSnapshots
  }
  private enum CodingKeys: String, CodingKey {
    case id, createdAt, question, engine, sources, output, assignmentID, instructionsSnapshot,
      promptSnapshots
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    createdAt = try c.decode(Date.self, forKey: .createdAt)
    question = try c.decode(String.self, forKey: .question)
    engine = try c.decode(MentorEngine.self, forKey: .engine)
    sources = try c.decode([ApprovedSource].self, forKey: .sources)
    output = try c.decode(MentorOutput.self, forKey: .output)
    assignmentID = try c.decodeIfPresent(UUID.self, forKey: .assignmentID)
    instructionsSnapshot = try c.decodeIfPresent(String.self, forKey: .instructionsSnapshot)
    promptSnapshots = try c.decodeIfPresent([String].self, forKey: .promptSnapshots) ?? []
  }
}
public struct AppData: Codable, Equatable {
  public var profile: AcademicProfile
  public var subjects: [Subject]
  public var assignments: [Assignment]
  public var goals: [LearningGoal]
  public var reports: [MentorReport]
  public var focusActions: [FocusAction]
  public init(
    profile: AcademicProfile = .init(), subjects: [Subject] = [], assignments: [Assignment] = [],
    goals: [LearningGoal] = [], reports: [MentorReport] = [], focusActions: [FocusAction] = []
  ) {
    self.profile = profile
    self.subjects = subjects
    self.assignments = assignments
    self.goals = goals
    self.reports = reports
    self.focusActions = focusActions
  }
  private enum CodingKeys: String, CodingKey {
    case profile, subjects, assignments, goals, reports, focusActions
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    profile = try c.decode(AcademicProfile.self, forKey: .profile)
    subjects = try c.decode([Subject].self, forKey: .subjects)
    assignments = try c.decode([Assignment].self, forKey: .assignments)
    goals = try c.decode([LearningGoal].self, forKey: .goals)
    reports = try c.decode([MentorReport].self, forKey: .reports)
    focusActions = try c.decodeIfPresent([FocusAction].self, forKey: .focusActions) ?? []
  }
  public var averageGrade: Double? {
    let grades = assignments.filter { !$0.isDemo }.compactMap(\.grade)
    return grades.isEmpty ? nil : grades.reduce(0, +) / Double(grades.count)
  }
}
public struct GenerationTicket: Hashable {
  public let id: UUID
  public let requestID: UUID
  public init(id: UUID = UUID(), requestID: UUID) {
    self.id = id
    self.requestID = requestID
  }
}
public enum UniCoachError: LocalizedError, Equatable {
  case invalidQuestion, noSources, emptySource, contextTooLong, sourceChanged, invalidEvidence,
    cancelled, invalidRelationship, invalidGrade, engineUnavailable
  public var errorDescription: String? {
    switch self {
    case .invalidQuestion: return "Enter a question for your mentor."
    case .noSources: return "Select at least one source."
    case .emptySource: return "Selected sources must contain approved text."
    case .contextTooLong: return "The approved context is too long."
    case .sourceChanged: return "A selected source changed. Review your consent again."
    case .invalidEvidence: return "The response must reference approved sources."
    case .cancelled: return "This request was cancelled or is no longer active."
    case .invalidRelationship: return "The linked subject could not be found."
    case .invalidGrade: return "Grade must be between 0 and 100."
    case .engineUnavailable: return "This engine is unavailable."
    }
  }
}
