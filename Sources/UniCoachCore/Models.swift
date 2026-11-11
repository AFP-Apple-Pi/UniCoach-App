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
  private enum CodingKeys: String, CodingKey {
    case name, university, course, learningGoal, onboardingComplete
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    name = try c.decode(String.self, forKey: .name)
    university = try c.decode(String.self, forKey: .university)
    course = try c.decode(String.self, forKey: .course)
    learningGoal = try c.decodeIfPresent(String.self, forKey: .learningGoal) ?? ""
    onboardingComplete = try c.decode(Bool.self, forKey: .onboardingComplete)
  }
  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(name, forKey: .name)
    try c.encode(university, forKey: .university)
    try c.encode(course, forKey: .course)
    try c.encode(onboardingComplete, forKey: .onboardingComplete)
  }
}
public struct Subject: Codable, Identifiable, Equatable {
  public var id: UUID
  public var code: String, name: String
  public var credits: Double
  public var tutor: String, colorHex: String, academicGoal: String
  public var isDemo: Bool
  public var semester: String?
  public var description: String
  public var sourceReferences: [DocumentSourceReference]
  public init(
    id: UUID = UUID(), code: String = "", name: String = "", credits: Double = 0,
    tutor: String = "", colorHex: String = "#6750A4", academicGoal: String = "",
    isDemo: Bool = false, semester: String? = nil, description: String = "",
    sourceReferences: [DocumentSourceReference] = []
  ) {
    self.id = id
    self.code = code
    self.name = name
    self.credits = credits
    self.tutor = tutor
    self.colorHex = colorHex
    self.academicGoal = academicGoal
    self.isDemo = isDemo
    self.semester = semester
    self.description = description
    self.sourceReferences = sourceReferences
  }
  private enum CodingKeys: String, CodingKey {
    case id, code, name, credits, tutor, colorHex, academicGoal, isDemo, semester, description, sourceReferences
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    code = try c.decode(String.self, forKey: .code)
    name = try c.decode(String.self, forKey: .name)
    credits = try c.decode(Double.self, forKey: .credits)
    tutor = try c.decode(String.self, forKey: .tutor)
    colorHex = try c.decode(String.self, forKey: .colorHex)
    academicGoal = try c.decodeIfPresent(String.self, forKey: .academicGoal) ?? ""
    isDemo = try c.decode(Bool.self, forKey: .isDemo)
    semester = try c.decodeIfPresent(String.self, forKey: .semester)
    description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
    sourceReferences = try c.decodeIfPresent([DocumentSourceReference].self, forKey: .sourceReferences) ?? []
  }
  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(code, forKey: .code)
    try c.encode(name, forKey: .name)
    try c.encode(credits, forKey: .credits)
    try c.encode(tutor, forKey: .tutor)
    try c.encode(colorHex, forKey: .colorHex)
    try c.encode(isDemo, forKey: .isDemo)
    try c.encodeIfPresent(semester, forKey: .semester)
    if !description.isEmpty { try c.encode(description, forKey: .description) }
    if !sourceReferences.isEmpty { try c.encode(sourceReferences, forKey: .sourceReferences) }
  }
}
public struct Assignment: Codable, Identifiable, Equatable {
  public var id: UUID
  public var subjectID: UUID
  public var title: String, brief: String
  public var dueDate: Date?
  public var createdAt: Date?
  public var score: Double?
  public var outOf: Double?
  public var tutorFeedback: String, reflection: String
  public var isDemo: Bool
  public var submittedWork: String
  public var collaborationType: String, assignmentFormat: String, targetGrade: String
  public var weighting: Double?
  public var sourceReferences: [DocumentSourceReference]
  public var currentStage: String, approach: String, challenges: String, collaboration: String, rubric: String
  public var hasReflection: Bool {
    [reflection, currentStage, approach, challenges, collaboration, rubric].contains {
      !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  }
  public var percentage: Double? {
    guard let score, let outOf, outOf > 0 else { return nil }
    return score / outOf * 100
  }
  public var chartDate: Date? { dueDate ?? createdAt }
  // Compatibility for older callers; new UI uses score and outOf directly.
  public var grade: Double? {
    get { percentage }
    set {
      score = newValue
      outOf = newValue == nil ? nil : 100
    }
  }
  public init(
    id: UUID = UUID(), subjectID: UUID, title: String = "", brief: String = "",
    dueDate: Date? = Date(), grade: Double? = nil, tutorFeedback: String = "",
    reflection: String = "", isDemo: Bool = false, submittedWork: String = "", score: Double? = nil,
    outOf: Double? = nil, createdAt: Date? = Date(), collaborationType: String = "",
    assignmentFormat: String = "", targetGrade: String = "", weighting: Double? = nil,
    currentStage: String = "", approach: String = "", challenges: String = "",
    collaboration: String = "", rubric: String = "", sourceReferences: [DocumentSourceReference] = []
  ) {
    self.id = id
    self.subjectID = subjectID
    self.title = title
    self.brief = brief
    self.dueDate = dueDate
    self.createdAt = createdAt
    self.score = score ?? grade
    self.outOf = outOf ?? (grade == nil ? nil : 100)
    self.tutorFeedback = tutorFeedback
    self.reflection = reflection
    self.isDemo = isDemo
    self.submittedWork = submittedWork
    self.collaborationType = collaborationType
    self.assignmentFormat = assignmentFormat
    self.targetGrade = targetGrade
    self.weighting = weighting
    self.currentStage = currentStage
    self.approach = approach
    self.challenges = challenges
    self.collaboration = collaboration
    self.rubric = rubric
    self.sourceReferences = sourceReferences
  }
  private enum CodingKeys: String, CodingKey {
    case id, subjectID, title, brief, dueDate, createdAt, grade, score, outOf, tutorFeedback,
      reflection, isDemo, submittedWork, collaborationType, assignmentFormat, targetGrade,
      weighting, currentStage, approach, challenges, collaboration, rubric, sourceReferences
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    subjectID = try c.decode(UUID.self, forKey: .subjectID)
    title = try c.decode(String.self, forKey: .title)
    brief = try c.decode(String.self, forKey: .brief)
    dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate)
    createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
    let legacy = try c.decodeIfPresent(Double.self, forKey: .grade)
    score = try c.decodeIfPresent(Double.self, forKey: .score) ?? legacy
    outOf = try c.decodeIfPresent(Double.self, forKey: .outOf) ?? (legacy == nil ? nil : 100)
    tutorFeedback = try c.decode(String.self, forKey: .tutorFeedback)
    reflection = try c.decode(String.self, forKey: .reflection)
    isDemo = try c.decode(Bool.self, forKey: .isDemo)
    submittedWork = try c.decodeIfPresent(String.self, forKey: .submittedWork) ?? ""
    collaborationType = try c.decodeIfPresent(String.self, forKey: .collaborationType) ?? ""
    assignmentFormat = try c.decodeIfPresent(String.self, forKey: .assignmentFormat) ?? ""
    targetGrade = try c.decodeIfPresent(String.self, forKey: .targetGrade) ?? ""
    weighting = try c.decodeIfPresent(Double.self, forKey: .weighting)
    currentStage = try c.decodeIfPresent(String.self, forKey: .currentStage) ?? ""
    approach = try c.decodeIfPresent(String.self, forKey: .approach) ?? ""
    challenges = try c.decodeIfPresent(String.self, forKey: .challenges) ?? ""
    collaboration = try c.decodeIfPresent(String.self, forKey: .collaboration) ?? ""
    rubric = try c.decodeIfPresent(String.self, forKey: .rubric) ?? ""
    sourceReferences = try c.decodeIfPresent([DocumentSourceReference].self, forKey: .sourceReferences) ?? []
  }
  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(subjectID, forKey: .subjectID)
    try c.encode(title, forKey: .title)
    try c.encode(brief, forKey: .brief)
    try c.encodeIfPresent(dueDate, forKey: .dueDate)
    try c.encodeIfPresent(createdAt, forKey: .createdAt)
    try c.encodeIfPresent(score, forKey: .score)
    try c.encodeIfPresent(outOf, forKey: .outOf)
    try c.encode(tutorFeedback, forKey: .tutorFeedback)
    try c.encode(reflection, forKey: .reflection)
    try c.encode(isDemo, forKey: .isDemo)
    try c.encode(submittedWork, forKey: .submittedWork)
    if !collaborationType.isEmpty { try c.encode(collaborationType, forKey: .collaborationType) }
    if !assignmentFormat.isEmpty { try c.encode(assignmentFormat, forKey: .assignmentFormat) }
    if !targetGrade.isEmpty { try c.encode(targetGrade, forKey: .targetGrade) }
    try c.encodeIfPresent(weighting, forKey: .weighting)
    if !currentStage.isEmpty { try c.encode(currentStage, forKey: .currentStage) }
    if !approach.isEmpty { try c.encode(approach, forKey: .approach) }
    if !challenges.isEmpty { try c.encode(challenges, forKey: .challenges) }
    if !collaboration.isEmpty { try c.encode(collaboration, forKey: .collaboration) }
    if !rubric.isEmpty { try c.encode(rubric, forKey: .rubric) }
    if !sourceReferences.isEmpty { try c.encode(sourceReferences, forKey: .sourceReferences) }
  }
}
public struct LearningGoal: Codable, Identifiable, Equatable {
  public var id: UUID
  public var subjectID: UUID?
  public var title: String
  public var isComplete: Bool
  public var sourceReportID: UUID?
  public var createdAt: Date?
  public var completedAt: Date?
  public var originAssignmentID: UUID?
  public var legacyFocusStatus: FocusStatus?
  public var findingIndex: Int?
  public var isDemo: Bool
  public var focusUpdatedAt: Date?
  public var isAdviceGoal: Bool
  public var isCompleted: Bool {
    get { isComplete }
    set { isComplete = newValue }
  }
  public init(
    id: UUID = UUID(), subjectID: UUID? = nil, title: String = "", isCompleted: Bool = false,
    sourceReportID: UUID? = nil, createdAt: Date? = Date(), completedAt: Date? = nil,
    originAssignmentID: UUID? = nil, legacyFocusStatus: FocusStatus? = nil,
    findingIndex: Int? = nil, isDemo: Bool = false, focusUpdatedAt: Date? = nil,
    isAdviceGoal: Bool = false
  ) {
    self.id = id
    self.subjectID = subjectID
    self.title = title
    self.isComplete = isCompleted
    self.sourceReportID = sourceReportID
    self.createdAt = createdAt
    self.completedAt = completedAt
    self.originAssignmentID = originAssignmentID
    self.legacyFocusStatus = legacyFocusStatus
    self.findingIndex = findingIndex
    self.isDemo = isDemo
    self.focusUpdatedAt = focusUpdatedAt
    self.isAdviceGoal = isAdviceGoal
  }
  private enum CodingKeys: String, CodingKey {
    case id, subjectID, title, isCompleted, isComplete, sourceReportID, createdAt, completedAt,
      originAssignmentID, legacyFocusStatus, findingIndex, isDemo, focusUpdatedAt, isAdviceGoal
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    subjectID = try c.decodeIfPresent(UUID.self, forKey: .subjectID)
    title = try c.decode(String.self, forKey: .title)
    isComplete =
      try c.decodeIfPresent(Bool.self, forKey: .isComplete)
      ?? c.decode(Bool.self, forKey: .isCompleted)
    sourceReportID = try c.decodeIfPresent(UUID.self, forKey: .sourceReportID)
    createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
    completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
    originAssignmentID = try c.decodeIfPresent(UUID.self, forKey: .originAssignmentID)
    legacyFocusStatus = try c.decodeIfPresent(FocusStatus.self, forKey: .legacyFocusStatus)
    findingIndex = try c.decodeIfPresent(Int.self, forKey: .findingIndex)
    isDemo = try c.decodeIfPresent(Bool.self, forKey: .isDemo) ?? false
    focusUpdatedAt = try c.decodeIfPresent(Date.self, forKey: .focusUpdatedAt)
    isAdviceGoal = try c.decodeIfPresent(Bool.self, forKey: .isAdviceGoal) ?? false
  }
  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encodeIfPresent(subjectID, forKey: .subjectID)
    try c.encode(title, forKey: .title)
    try c.encode(isComplete, forKey: .isComplete)
    try c.encodeIfPresent(sourceReportID, forKey: .sourceReportID)
    try c.encodeIfPresent(createdAt, forKey: .createdAt)
    try c.encodeIfPresent(completedAt, forKey: .completedAt)
    try c.encodeIfPresent(originAssignmentID, forKey: .originAssignmentID)
    try c.encodeIfPresent(legacyFocusStatus, forKey: .legacyFocusStatus)
    try c.encodeIfPresent(findingIndex, forKey: .findingIndex)
    try c.encode(isDemo, forKey: .isDemo)
    try c.encodeIfPresent(focusUpdatedAt, forKey: .focusUpdatedAt)
    try c.encode(isAdviceGoal, forKey: .isAdviceGoal)
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
public enum MentorPurpose: String, Codable {
  case feedbackReview, mentorQuestion
}
public struct ConsentDraft {
  public let purpose: MentorPurpose
  public var question: String
  public var engine: MentorEngine
  public var assignmentID: UUID?
  public var conversation: MentorConversationSnapshot?
  public private(set) var selectedSources: [ContextSource]
  internal var originals: [String: String] = [:]
  public init(
    question: String = "", engine: MentorEngine = .contextualOffline, assignmentID: UUID? = nil,
    purpose: MentorPurpose = .feedbackReview, conversation: MentorConversationSnapshot? = nil
  ) {
    self.conversation = conversation
    self.purpose = purpose
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
  public let purpose: MentorPurpose
  public let question: String
  public let engine: MentorEngine
  public let sources: [ApprovedSource]
  public let assignmentID: UUID?
  public let conversation: MentorConversationSnapshot?
  internal let assignmentFingerprint: String?
  public init(
    id: UUID = UUID(), createdAt: Date = Date(), question: String, engine: MentorEngine,
    sources: [ApprovedSource], assignmentID: UUID? = nil, assignmentFingerprint: String? = nil,
    purpose: MentorPurpose = .feedbackReview, conversation: MentorConversationSnapshot? = nil
  ) {
    self.conversation = conversation
    self.id = id
    self.createdAt = createdAt
    self.purpose = purpose
    self.question = question
    self.engine = engine
    self.sources = sources
    self.assignmentID = assignmentID
    self.assignmentFingerprint = assignmentFingerprint
  }
  private enum CodingKeys: String, CodingKey {
    case id, createdAt, purpose, question, engine, sources, assignmentID, assignmentFingerprint, conversation
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(UUID.self, forKey: .id)
    createdAt = try c.decode(Date.self, forKey: .createdAt)
    conversation = try c.decodeIfPresent(MentorConversationSnapshot.self, forKey: .conversation)
    purpose = try c.decodeIfPresent(MentorPurpose.self, forKey: .purpose) ?? .feedbackReview
    question = try c.decode(String.self, forKey: .question)
    engine = try c.decode(MentorEngine.self, forKey: .engine)
    sources = try c.decode([ApprovedSource].self, forKey: .sources)
    assignmentID = try c.decodeIfPresent(UUID.self, forKey: .assignmentID)
    assignmentFingerprint = try c.decodeIfPresent(String.self, forKey: .assignmentFingerprint)
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
public struct AdviceItem: Codable, Equatable {
  public var text: String
  public var tutorQuote: String
  public init(text: String, tutorQuote: String) {
    self.text = text
    self.tutorQuote = tutorQuote
  }
}
public struct CoachingAdvice: Codable, Equatable {
  public var keepDoing: [AdviceItem]
  public var improve: [AdviceItem]
  public var nextStep: String
  public init(keepDoing: [AdviceItem], improve: [AdviceItem], nextStep: String) {
    self.keepDoing = keepDoing
    self.improve = improve
    self.nextStep = nextStep
  }
}
public struct MarkSummary: Equatable {
  public var score: Double
  public var outOf: Double
  public var gradedCount: Int
  public var percentage: Double? { outOf > 0 ? score / outOf * 100 : nil }
  public init(score: Double, outOf: Double, gradedCount: Int) {
    self.score = score
    self.outOf = outOf
    self.gradedCount = gradedCount
  }
}
public struct MentorOutput: Codable, Equatable {
  public var summary: String
  public var recommendations: [String]
  public var evidenceSourceIDs: [String]
  public var findings: [ReviewFinding]?
  public var advice: CoachingAdvice?
  public init(
    summary: String, recommendations: [String], evidenceSourceIDs: [String],
    findings: [ReviewFinding]? = nil, advice: CoachingAdvice? = nil
  ) {
    self.summary = summary
    self.recommendations = recommendations
    self.evidenceSourceIDs = evidenceSourceIDs
    self.findings = findings
    self.advice = advice
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
  public let processingSteps: [ModelProcessingStep]?
  public init(
    id: UUID = UUID(), createdAt: Date = Date(), question: String, engine: MentorEngine,
    sources: [ApprovedSource], output: MentorOutput, assignmentID: UUID? = nil,
    instructionsSnapshot: String? = nil, promptSnapshots: [String] = [],
    processingSteps: [ModelProcessingStep]? = nil
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
    self.processingSteps = processingSteps
  }
  private enum CodingKeys: String, CodingKey {
    case id, createdAt, question, engine, sources, output, assignmentID, instructionsSnapshot,
      promptSnapshots, processingSteps
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
    processingSteps = try c.decodeIfPresent([ModelProcessingStep].self, forKey: .processingSteps)
  }
}
public struct AppData: Codable, Equatable {
  public static let currentSchemaVersion = 1
  public var schemaVersion: Int
  public var profile: AcademicProfile
  public var subjects: [Subject]
  public var assignments: [Assignment]
  public var goals: [LearningGoal]
  public var reports: [MentorReport]
  public var mentorAnswers: [MentorAnswer]
  // Read-only compatibility view, backed entirely by unified goals.
  public var focusActions: [FocusAction] {
    goals.compactMap { goal in
      guard let report = goal.sourceReportID, let assignment = goal.originAssignmentID,
        let subject = goal.subjectID, let status = goal.legacyFocusStatus,
        let created = goal.createdAt
      else { return nil }
      return FocusAction(
        id: goal.id, reportID: report, assignmentID: assignment, subjectID: subject,
        title: goal.title, status: status, createdAt: created,
        updatedAt: goal.focusUpdatedAt ?? created,
        findingIndex: goal.findingIndex, isDemo: goal.isDemo)
    }
  }
  public init(
    profile: AcademicProfile = .init(), subjects: [Subject] = [], assignments: [Assignment] = [],
    goals: [LearningGoal] = [], reports: [MentorReport] = [], mentorAnswers: [MentorAnswer] = []
  ) {
    schemaVersion = Self.currentSchemaVersion
    self.profile = profile
    self.subjects = subjects
    self.assignments = assignments
    self.goals = goals
    self.reports = reports
    self.mentorAnswers = mentorAnswers
  }
  private enum CodingKeys: String, CodingKey {
    case schemaVersion, profile, subjects, assignments, goals, reports, mentorAnswers, focusActions
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let version = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
    guard version >= 0 && version <= Self.currentSchemaVersion else {
      throw DecodingError.dataCorruptedError(
        forKey: .schemaVersion, in: c, debugDescription: "Unsupported schema version")
    }
    profile = try c.decode(AcademicProfile.self, forKey: .profile)
    subjects = try c.decode([Subject].self, forKey: .subjects)
    assignments = try c.decode([Assignment].self, forKey: .assignments)
    goals = try c.decode([LearningGoal].self, forKey: .goals)
    reports = try c.decode([MentorReport].self, forKey: .reports)
    mentorAnswers = try c.decodeIfPresent([MentorAnswer].self, forKey: .mentorAnswers) ?? []
    if version == 0 {
      let legacyFocus = try c.decodeIfPresent([FocusAction].self, forKey: .focusActions) ?? []
      for focus in legacyFocus where !goals.contains(where: { $0.id == focus.id }) {
        goals.append(
          LearningGoal(
            id: focus.id, subjectID: focus.subjectID, title: focus.title,
            sourceReportID: focus.reportID, createdAt: focus.createdAt,
            originAssignmentID: focus.assignmentID, legacyFocusStatus: focus.status,
            findingIndex: focus.findingIndex,
            isDemo: focus.isDemo
              || assignments.contains(where: { $0.id == focus.assignmentID && $0.isDemo })
              || subjects.contains(where: { $0.id == focus.subjectID && $0.isDemo }),
            focusUpdatedAt: focus.updatedAt)
        )
      }
      func migratedID(_ key: String) -> UUID {
        var h: UInt64 = 14_695_981_039_346_656_037
        for b in key.utf8 { h = (h ^ UInt64(b)) &* 1_099_511_628_211 }
        func byte(_ shift: Int) -> UInt8 { UInt8(truncatingIfNeeded: h >> shift) }
        // Keep the same byte layout and version and variant bits as the original migration.
        return UUID(uuid: (
          byte(56), byte(48), byte(40), byte(32), byte(24), byte(16),
          0x40 | (byte(8) & 0x0f), byte(0), 0xa0 | (byte(56) & 0x0f), byte(48),
          byte(40), byte(32), byte(24), byte(16), byte(8), byte(0)
        ))
      }
      let profileText = profile.learningGoal
      if !profileText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        let id = migratedID("profile:" + profileText)
        if !goals.contains(where: { $0.id == id }) {
          goals.append(LearningGoal(id: id, title: profileText, createdAt: nil))
        }
      }
      profile.learningGoal = ""
      for i in subjects.indices {
        let text = subjects[i].academicGoal
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          let id = migratedID("subject:" + subjects[i].id.uuidString + ":" + text)
          if !goals.contains(where: { $0.id == id }) {
            goals.append(
              LearningGoal(
                id: id, subjectID: subjects[i].id, title: text, createdAt: nil,
                isDemo: subjects[i].isDemo))
          }
        }
        subjects[i].academicGoal = ""
      }
    }
    schemaVersion = Self.currentSchemaVersion
  }
  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(schemaVersion, forKey: .schemaVersion)
    try c.encode(profile, forKey: .profile)
    try c.encode(subjects, forKey: .subjects)
    try c.encode(assignments, forKey: .assignments)
    try c.encode(goals, forKey: .goals)
    try c.encode(reports, forKey: .reports)
    if !mentorAnswers.isEmpty { try c.encode(mentorAnswers, forKey: .mentorAnswers) }
  }
  public var averageGrade: Double? {
    let grades = assignments.filter { !$0.isDemo }.compactMap(\.percentage)
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
    cancelled, invalidRelationship, invalidGrade, invalidCredits, duplicateImport, engineUnavailable, emptyAnswer, contextProcessingFailed
  public var errorDescription: String? {
    switch self {
    case .contextProcessingFailed: return "The approved material could not be processed within the on-device model limits. Try a smaller request."
    case .invalidQuestion: return "Enter a question for your mentor."
    case .noSources: return "Select at least one source."
    case .emptySource: return "Selected sources must contain approved text."
    case .contextTooLong: return "The question, conversation and approved context are too long. Remove context or start a new conversation."
    case .sourceChanged: return "A selected source or conversation changed. Review your consent again."
    case .invalidEvidence: return "The response must reference approved sources."
    case .cancelled: return "This request was cancelled or is no longer active."
    case .invalidRelationship: return "The linked subject could not be found."
    case .invalidCredits: return "Enter a valid nonnegative number of credits."
    case .duplicateImport: return "Possible duplicate records need your confirmation before importing."
    case .invalidGrade:
      return
        "Enter a positive total. If marks are entered, they must be between zero and the total."
    case .engineUnavailable: return "This engine is unavailable."
    case .emptyAnswer: return "The mentor returned an empty answer. Try asking again."
    }
  }
}
