import Foundation

public struct AcademicProfile: Codable, Equatable {
    public var name: String, university: String, course: String, learningGoal: String
    public var onboardingComplete: Bool
    public init(name: String = "", university: String = "", course: String = "", learningGoal: String = "", onboardingComplete: Bool = false) {
        self.name = name; self.university = university; self.course = course; self.learningGoal = learningGoal; self.onboardingComplete = onboardingComplete
    }
}
public struct Subject: Codable, Identifiable, Equatable {
    public var id: UUID; public var code: String, name: String; public var credits: Double; public var tutor: String, colorHex: String, academicGoal: String; public var isDemo: Bool
    public init(id: UUID = UUID(), code: String = "", name: String = "", credits: Double = 0, tutor: String = "", colorHex: String = "#6750A4", academicGoal: String = "", isDemo: Bool = false) {
        self.id = id; self.code = code; self.name = name; self.credits = credits; self.tutor = tutor; self.colorHex = colorHex; self.academicGoal = academicGoal; self.isDemo = isDemo
    }
}
public struct Assignment: Codable, Identifiable, Equatable {
    public var id: UUID; public var subjectID: UUID; public var title: String, brief: String; public var dueDate: Date; public var grade: Double?; public var tutorFeedback: String, reflection: String; public var isDemo: Bool
    public init(id: UUID = UUID(), subjectID: UUID, title: String = "", brief: String = "", dueDate: Date = Date(), grade: Double? = nil, tutorFeedback: String = "", reflection: String = "", isDemo: Bool = false) {
        self.id = id; self.subjectID = subjectID; self.title = title; self.brief = brief; self.dueDate = dueDate; self.grade = grade; self.tutorFeedback = tutorFeedback; self.reflection = reflection; self.isDemo = isDemo
    }
}
public struct LearningGoal: Codable, Identifiable, Equatable {
    public var id: UUID; public var subjectID: UUID?; public var title: String; public var isCompleted: Bool
    public init(id: UUID = UUID(), subjectID: UUID? = nil, title: String = "", isCompleted: Bool = false) { self.id = id; self.subjectID = subjectID; self.title = title; self.isCompleted = isCompleted }
}
public enum MentorEngine: String, Codable, CaseIterable {
    case appleOnDevice, contextualOffline
    public var displayName: String { switch self { case .appleOnDevice: return "Apple on-device"; case .contextualOffline: return "Contextual offline (not AI)" } }
}
public struct ContextSource: Identifiable, Equatable {
    public var id: String, title: String, text: String; public let fingerprint: String
    public init(id: String, title: String, text: String, fingerprint: String = "") { self.id = id; self.title = title; self.text = text; self.fingerprint = fingerprint }
}
public struct ApprovedSource: Codable, Identifiable, Equatable {
    public let id: String, title: String, text: String, originalFingerprint: String
    public init(id: String, title: String, text: String, originalFingerprint: String) { self.id = id; self.title = title; self.text = text; self.originalFingerprint = originalFingerprint }
}
public struct ConsentDraft {
    public var question: String; public var engine: MentorEngine; public var assignmentID: UUID?
    public private(set) var selectedSources: [ContextSource]
    internal var originals: [String: String] = [:]
    public init(question: String = "", engine: MentorEngine = .contextualOffline, assignmentID: UUID? = nil) { self.question = question; self.engine = engine; self.assignmentID = assignmentID; self.selectedSources = [] }
    public mutating func setSelected(_ selected: Bool, source: ContextSource) {
        if selected { if !selectedSources.contains(where: { $0.id == source.id }) { selectedSources.append(source); originals[source.id] = source.fingerprint } }
        else { selectedSources.removeAll { $0.id == source.id }; originals.removeValue(forKey: source.id) }
    }
    public mutating func setText(_ text: String, sourceID: String) { if let i = selectedSources.firstIndex(where: { $0.id == sourceID }) { selectedSources[i].text = text } }
}
public struct ApprovedRequest: Codable, Identifiable, Equatable {
    public let id: UUID; public let createdAt: Date; public let question: String; public let engine: MentorEngine; public let sources: [ApprovedSource]; public let assignmentID: UUID?; internal let assignmentFingerprint: String?
    public init(id: UUID = UUID(), createdAt: Date = Date(), question: String, engine: MentorEngine, sources: [ApprovedSource], assignmentID: UUID? = nil, assignmentFingerprint: String? = nil) { self.id = id; self.createdAt = createdAt; self.question = question; self.engine = engine; self.sources = sources; self.assignmentID = assignmentID; self.assignmentFingerprint = assignmentFingerprint }
}
public struct MentorOutput: Codable, Equatable {
    public var summary: String; public var recommendations: [String]; public var evidenceSourceIDs: [String]
    public init(summary: String, recommendations: [String], evidenceSourceIDs: [String]) { self.summary = summary; self.recommendations = recommendations; self.evidenceSourceIDs = evidenceSourceIDs }
}
public struct MentorReport: Codable, Identifiable, Equatable {
    public let id: UUID; public let createdAt: Date; public let question: String; public let engine: MentorEngine; public let sources: [ApprovedSource]; public let output: MentorOutput; public let assignmentID: UUID?
    public let instructionsSnapshot: String?; public let promptSnapshots: [String]
    public init(id: UUID = UUID(), createdAt: Date = Date(), question: String, engine: MentorEngine, sources: [ApprovedSource], output: MentorOutput, assignmentID: UUID? = nil, instructionsSnapshot: String? = nil, promptSnapshots: [String] = []) {
        self.id = id; self.createdAt = createdAt; self.question = question; self.engine = engine; self.sources = sources; self.output = output; self.assignmentID = assignmentID; self.instructionsSnapshot = instructionsSnapshot; self.promptSnapshots = promptSnapshots
    }
    private enum CodingKeys: String, CodingKey { case id, createdAt, question, engine, sources, output, assignmentID, instructionsSnapshot, promptSnapshots }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id); createdAt = try c.decode(Date.self, forKey: .createdAt)
        question = try c.decode(String.self, forKey: .question); engine = try c.decode(MentorEngine.self, forKey: .engine)
        sources = try c.decode([ApprovedSource].self, forKey: .sources); output = try c.decode(MentorOutput.self, forKey: .output)
        assignmentID = try c.decodeIfPresent(UUID.self, forKey: .assignmentID)
        instructionsSnapshot = try c.decodeIfPresent(String.self, forKey: .instructionsSnapshot)
        promptSnapshots = try c.decodeIfPresent([String].self, forKey: .promptSnapshots) ?? []
    }
}
public struct AppData: Codable, Equatable {
    public var profile: AcademicProfile; public var subjects: [Subject]; public var assignments: [Assignment]; public var goals: [LearningGoal]; public var reports: [MentorReport]
    public init(profile: AcademicProfile = .init(), subjects: [Subject] = [], assignments: [Assignment] = [], goals: [LearningGoal] = [], reports: [MentorReport] = []) { self.profile = profile; self.subjects = subjects; self.assignments = assignments; self.goals = goals; self.reports = reports }
    public var averageGrade: Double? { let grades = assignments.filter { !$0.isDemo }.compactMap(\.grade); return grades.isEmpty ? nil : grades.reduce(0, +) / Double(grades.count) }
}
public struct GenerationTicket: Hashable { public let id: UUID; public let requestID: UUID; public init(id: UUID = UUID(), requestID: UUID) { self.id = id; self.requestID = requestID } }
public enum UniCoachError: LocalizedError, Equatable {
    case invalidQuestion, noSources, emptySource, contextTooLong, sourceChanged, invalidEvidence, cancelled, invalidRelationship, invalidGrade, engineUnavailable
    public var errorDescription: String? { switch self {
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
    } }
}
