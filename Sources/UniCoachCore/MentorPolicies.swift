import Foundation

public enum MentorRelevance: String, Codable, Equatable { case relevant, partial, unrelated, uncertain }

public struct RelevanceAssessment: Codable, Equatable {
  public let verdict: MentorRelevance
  public let relevantIDs: [String]
  public let excludedIDs: [String]
  public init(verdict: MentorRelevance, relevantIDs: [String], excludedIDs: [String]) {
    self.verdict = verdict
    self.relevantIDs = relevantIDs
    self.excludedIDs = excludedIDs
  }
}

public enum RelevanceDecision: Equatable {
  case proceed(relevantIDs: [String], excludedIDs: [String])
  case clarify
}

public enum FeedbackPassageRelevance: String, Codable, Equatable {
  case relevant, unrelated, uncertain
}

public struct FeedbackRelevanceItem: Codable, Equatable {
  public let id: String
  public let verdict: FeedbackPassageRelevance
  public init(id: String, verdict: FeedbackPassageRelevance) {
    self.id = id
    self.verdict = verdict
  }
}

public enum RelevancePolicy {
  /// Derives the overall verdict locally from exactly one result per trusted passage.
  public static func assess(_ items: [FeedbackRelevanceItem], expectedIDs: [String]) -> RelevanceAssessment? {
    let expected = Set(expectedIDs)
    let known = items.filter { expected.contains($0.id) }
    let actual = Set(known.map(\.id))
    guard !expected.isEmpty, expected.count == expectedIDs.count,
      actual.count == known.count, actual == expected
    else { return nil }
    let byID = Dictionary(uniqueKeysWithValues: known.map { ($0.id, $0.verdict) })
    let relevant = expectedIDs.filter { byID[$0] == .relevant }
    let excluded = expectedIDs.filter { byID[$0] != .relevant }
    let verdict: MentorRelevance
    if excluded.isEmpty {
      verdict = .relevant
    } else if !relevant.isEmpty {
      verdict = .partial
    } else if known.allSatisfy({ $0.verdict == .unrelated }) {
      verdict = .unrelated
    } else {
      verdict = .uncertain
    }
    return RelevanceAssessment(verdict: verdict, relevantIDs: relevant, excludedIDs: excluded)
  }

  public static func decision(_ assessment: RelevanceAssessment, expectedIDs: [String]) -> RelevanceDecision {
    let expected = Set(expectedIDs)
    let relevant = Set(assessment.relevantIDs)
    let excluded = Set(assessment.excludedIDs)
    guard !expected.isEmpty, expected.count == expectedIDs.count,
      relevant.count == assessment.relevantIDs.count, excluded.count == assessment.excludedIDs.count,
      relevant.isDisjoint(with: excluded), relevant.union(excluded) == expected
    else { return .clarify }
    switch assessment.verdict {
    case .relevant where relevant == expected && excluded.isEmpty:
      return .proceed(relevantIDs: assessment.relevantIDs, excludedIDs: [])
    case .partial where !relevant.isEmpty && !excluded.isEmpty:
      return .proceed(relevantIDs: assessment.relevantIDs, excludedIDs: assessment.excludedIDs)
    default:
      return .clarify
    }
  }
}

public enum FeedbackTargetKind: String, Codable, Equatable { case specific, uncertain, notFeedback }
public enum FeedbackIntent: String, Codable, Equatable { case praise, request, both, unspecified }

public struct FeedbackTargetItem: Codable, Equatable {
  public let id: String
  public let kind: FeedbackTargetKind
  public let targetQuote: String
  public let intent: FeedbackIntent
  public init(id: String, kind: FeedbackTargetKind, targetQuote: String, intent: FeedbackIntent = .unspecified) {
    self.id = id
    self.kind = kind
    self.targetQuote = targetQuote
    self.intent = intent
  }
  private enum CodingKeys: String, CodingKey { case id, kind, targetQuote, intent }
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    kind = try container.decode(FeedbackTargetKind.self, forKey: .kind)
    targetQuote = try container.decode(String.self, forKey: .targetQuote)
    intent = try container.decodeIfPresent(FeedbackIntent.self, forKey: .intent) ?? .unspecified
  }
}

public enum FeedbackTargetPolicy {
  /// Accepts only specific targets quoted exactly from their own approved feedback passage.
  /// A semantic model assessment is still required; a matching quote alone proves provenance only.
  public static func acceptedIDs(_ items: [FeedbackTargetItem], feedbackByID: [String: String]) -> Set<String>? {
    let expected = Set(feedbackByID.keys)
    let known = items.filter { expected.contains($0.id) }
    let actual = Set(known.map(\.id))
    guard !expected.isEmpty, actual.count == known.count, actual == expected else { return nil }
    var accepted: Set<String> = []
    for item in known where item.kind == .specific && item.intent != .unspecified {
      guard !item.targetQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        let feedback = feedbackByID[item.id], containsQuotedPhrase(item.targetQuote, in: feedback)
      else { continue }
      accepted.insert(item.id)
    }
    return accepted
  }

  public static func allows(_ category: ReviewCategory, for item: FeedbackTargetItem) -> Bool {
    guard item.kind == .specific else { return false }
    switch (category, item.intent) {
    case (.keepDoing, .praise), (.keepDoing, .both), (.improve, .request), (.improve, .both): return true
    default: return false
    }
  }

  private static func containsQuotedPhrase(_ quote: String, in feedback: String) -> Bool {
    var start = feedback.startIndex
    while start < feedback.endIndex, let range = feedback.range(of: quote, range: start..<feedback.endIndex) {
      let before = range.lowerBound > feedback.startIndex ? feedback[feedback.index(before: range.lowerBound)] : nil
      let after = range.upperBound < feedback.endIndex ? feedback[range.upperBound] : nil
      func word(_ character: Character?) -> Bool { character.map { $0.isLetter || $0.isNumber } ?? false }
      let startsInsideWord = word(quote.first) && word(before)
      let endsInsideWord = word(quote.last) && word(after)
      if !startsInsideWord && !endsInsideWord { return true }
      start = feedback.index(after: range.lowerBound)
    }
    return false
  }
}

public enum PassageRole: Equatable { case work, feedback }

public enum PassageIndexPolicy {
  /// Maps a one-based alias suffix only when the exact role-specific alias is in the trusted catalogue.
  public static func alias(index: Int, role: PassageRole, availableIDs: Set<String>) -> String? {
    guard index > 0 else { return nil }
    let alias = (role == .work ? "W" : "F") + String(index)
    return availableIDs.contains(alias) ? alias : nil
  }
}

public enum FindingRelation: String, Codable, Equatable { case supported, unsupported, uncertain }

public enum FindingPolicy {
  public static func accepts(_ relation: FindingRelation, feedbackID: String, allowedFeedbackIDs: Set<String>) -> Bool {
    relation == .supported && allowedFeedbackIDs.contains(feedbackID)
  }
}

public enum StudyPlanConstraintKind: String, Codable, Equatable, Hashable {
  case sessionCount, minutesPerSession, totalMinutes, minutesPerDay
}
public enum StudyPlanRelation: String, Codable, Equatable { case exact, maximum, minimum }
public enum StudyPlanEvidenceOrigin: String, Codable, Equatable { case currentQuestion, history }
public enum StudyPlanUnit: String, Codable, Equatable { case count, minutes, hours }

public struct StudyPlanConstraint: Codable, Equatable {
  public let kind: StudyPlanConstraintKind
  public let relation: StudyPlanRelation
  public let value: Int
  public let evidence: String
  public let numberText: String
  public let unit: StudyPlanUnit
  public let origin: StudyPlanEvidenceOrigin
  public init(kind: StudyPlanConstraintKind, relation: StudyPlanRelation, value: Int, evidence: String, numberText: String, unit: StudyPlanUnit, origin: StudyPlanEvidenceOrigin) {
    self.kind = kind; self.relation = relation; self.value = value; self.evidence = evidence
    self.numberText = numberText; self.unit = unit; self.origin = origin
  }
}

public struct StudyPlanAvailability: Codable, Equatable {
  public let days: [String]
  public let evidence: String
  public let origin: StudyPlanEvidenceOrigin
  public init(days: [String], evidence: String, origin: StudyPlanEvidenceOrigin) {
    self.days = days; self.evidence = evidence; self.origin = origin
  }
}

public struct StudyPlanSession: Codable, Equatable {
  public let day: String
  public let minutes: Int
  public let task: String
  public let check: String
  public init(day: String, minutes: Int, task: String, check: String) {
    self.day = day; self.minutes = minutes; self.task = task; self.check = check
  }
}

public struct StudyPlanSlot: Codable, Equatable {
  public let day: String
  public let minutes: Int
  public init(day: String, minutes: Int) { self.day = day; self.minutes = minutes }
}

public struct StudyPlanTaskFill: Codable, Equatable {
  public let slotIndex: Int
  public let task: String
  public let check: String
  public init(slotIndex: Int, task: String, check: String) {
    self.slotIndex = slotIndex; self.task = task; self.check = check
  }
}

public enum StudyPlanValidation: Equatable { case valid, clarify }
public enum ExplicitAllocationRoute: Equatable {
  case explicit([StudyPlanConstraint])
  case needsVerifiedPlan
  case deferToModel
}

public enum StudyPlanValidator {
  public static func explicitAllocationRoute(
    currentQuestion: String, historyQuestions: [String]
  ) -> ExplicitAllocationRoute {
    if let constraints = explicitAllocationConstraints(currentQuestion: currentQuestion, historyQuestions: historyQuestions) {
      return .explicit(constraints)
    }
    return recognizesExplicitAllocationRequest(currentQuestion: currentQuestion) ? .needsVerifiedPlan : .deferToModel
  }

  /// Recognizes only complete, explicit single-allocation questions. Unrecognized or additional
  /// constraints return nil so the independently verified model path can handle them.
  public static func explicitAllocationConstraints(
    currentQuestion: String, historyQuestions: [String]
  ) -> [StudyPlanConstraint]? {
    let timing = #"\b(?:minutes?|mins?|hours?|hrs?|sessions?|blocks?|monday|tuesday|wednesday|thursday|friday|saturday|sunday|weekdays?|weekends?|days?|weeks?)\b"#
    guard historyQuestions.allSatisfy({ !matches(timing, in: $0) || parseExplicitAllocation($0) != nil }) else { return nil }
    return parseExplicitAllocation(currentQuestion)
  }

  /// Signals a clear scheduling request that requires the independently verified plan path
  /// when the narrow exact-allocation grammar cannot account for the entire request.
  public static func recognizesExplicitAllocationRequest(currentQuestion: String) -> Bool {
    guard !containsQuotedMaterial(currentQuestion) else { return false }
    if parseExplicitAllocation(currentQuestion) != nil { return true }
    let text = currentQuestion.lowercased()
    if isConceptualQuestion(text) { return false }
    let lead = #"^\s*(?:(?:actually|now)\s*,?\s*)?(?:my\s+(?:availability|schedule|time)\s+(?:has\s+)?changed\s*[:,.]\s*)?(?:i\s+(?:now\s+)?(?:have|need|want|can\s+(?:study|do|fit|schedule))\s+)"#
    let allocation = #"(?:[0-9]+|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)(?:\s|(?=[x×*]))"#
    let embeddedLead = #"(?:^|[.!?:;]\s*)i\s+(?:now\s+)?have\s+(?:only\s+|at\s+most\s+|up\s+to\s+)?"#
    let hasAllocationLead = (matches(lead + allocation, in: text) || matches(embeddedLead + allocation, in: text))
      && matches(#"\b(?:sessions?|blocks?|minutes?|mins?)\b|[×*]|[0-9]\s*x\s*[0-9]"#, in: text)
    let directScheduling = matches(#"^\s*(?:please\s+)?(?:help\s+me\s+)?(?:plan|schedule)\b"#, in: text)
      || matches(#"^\s*(?:can|could|would)\s+you\s+(?:help\s+me\s+)?(?:plan|schedule)\b"#, in: text)
      || matches(#"^\s*i\s+(?:need|want)\s+(?:a\s+)?(?:study\s+)?(?:plan|schedule)\b"#, in: text)
    let genericAction = matches(#"^\s*(?:please\s+)?(?:help\s+me\s+)?(?:make|create|build|organise|organize)\b"#, in: text)
      || matches(#"^\s*(?:can|could|would)\s+you\s+(?:help\s+me\s+)?(?:make|create|build|organise|organize)\b"#, in: text)
    let schedulingObject = matches(#"\b(?:plan|schedule|timetable|sessions?|blocks?|minutes?|mins?|hours?|hrs?)\b|[×*]"#, in: text)
    return hasAllocationLead || directScheduling || (genericAction && schedulingObject)
  }

  private static func isConceptualQuestion(_ text: String) -> Bool {
    matches(#"\bwhat\s+does\b[\s\S]*\bmean\b"#, in: text)
      || matches(#"\bwhat\s+(?:is|does)\b[\s\S]*\b(?:meaning|definition)\b"#, in: text)
      || matches(#"\b(?:is|are)\s+(?:that|this|it)\s+considered\b"#, in: text)
      || matches(#"\bdoes\s+(?:that|this|it)\s+count\s+as\b"#, in: text)
  }

  private static func matches(_ pattern: String, in text: String) -> Bool {
    guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
    return expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
  }

  private static func containsQuotedMaterial(_ value: String) -> Bool {
    let characters = Array(value)
    for index in characters.indices {
      let character = characters[index]
      if "\"‘“”«»`".contains(character) { return true }
      if character == "'" || character == "’" {
        let before = index > 0 ? characters[index - 1] : nil
        let after = index + 1 < characters.count ? characters[index + 1] : nil
        if before?.isLetter != true || after?.isLetter != true { return true }
      }
    }
    return false
  }

  private static func parseExplicitAllocation(_ question: String) -> [StudyPlanConstraint]? {
    // Quoted material may be a source instruction rather than the student's own allocation.
    guard !containsQuotedMaterial(question) else { return nil }
    if isConceptualQuestion(question) { return nil }
    let ones = "(?:one|two|three|four|five|six|seven|eight|nine)"
    let small = "(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen)"
    let tens = "(?:twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety)"
    let number = "(?:[0-9]+|" + tens + "(?:[ -]" + ones + ")?|" + small + ")"
    let prefix = #"^\s*(?:(?:actually|now)\s*,?\s*)?(?:my\s+(?:availability|schedule|time)\s+(?:has\s+)?changed\s*[:,.]\s*)?(?:i\s+(?:now\s+)?(?:have|need|want|can\s+(?:study|do|fit|schedule)|would\s+like\s+to\s+(?:study|do|plan|schedule))\s+|(?:please\s+)?(?:plan|schedule|make|create|organize|organise)\s+(?:me\s+)?|(?:please\s+)?help\s+me\s+(?:plan|schedule|organize|organise)\s+|(?:can|could|would)\s+you\s+(?:make|create|plan|schedule|build)\s+(?:(?:me\s+)?a\s+)?(?:study\s+)?plan\s+(?:for|with)\s+)"#
    let unit = #"(?:minutes?|mins?|min)"#
    let tail = #"(?<tail>[\s\S]*)$"#
    let patterns = [
      prefix + "(?<count>" + number + #")\s+(?<duration>"# + number + #")\s*-?\s*"# + unit + #"\s+(?:study\s+)?(?:sessions?|blocks?)"# + tail,
      prefix + "(?<count>" + number + #")\s+(?:study\s+)?(?:sessions?|blocks?)\s+(?:(?:of|lasting|for)\s+)?(?<duration>"# + number + #")\s*-?\s*"# + unit + tail,
      prefix + "(?<count>" + number + #")\s*[x×*]\s*(?<duration>"# + number + #")\s*-?\s*"# + unit + tail,
    ]
    let forbiddenTail = Set([
      "no", "not", "never", "cannot", "cant", "dont", "without", "except", "unless", "instead",
      "ignore", "forget", "override", "instruction", "instructions", "system", "prompt", "role", "pretend",
      "minute", "minutes", "min", "mins", "hour", "hours", "hr", "hrs", "day", "days", "week", "weeks",
      "month", "months", "second", "seconds", "fortnight", "fortnights", "year", "years", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
      "weekday", "weekdays", "weekend", "weekends", "morning", "afternoon", "evening", "night", "tomorrow",
      "today", "daily", "weekly", "deadline", "before", "after", "until", "between", "break", "breaks",
      "more", "less", "maximum", "minimum", "max", "min", "only", "least", "most", "total", "per",
      "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
      "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty", "thirty",
      "forty", "fifty", "sixty", "seventy", "eighty", "ninety", "hundred", "thousand",
    ])
    // A total budget before the session count is an upper bound, not a per-session claim.
    let reverse = #"(?:^|[.!?:;]\s*)i\s+(?:now\s+)?have\s+(?:only|at\s+most|up\s+to)\s+(?<duration>"# + number + #")\s*"# + unit + #"\s+(?:in|for|across)\s+(?<count>"# + number + #")\s+(?:study\s+)?(?:sessions?|blocks?)"# + tail
    let countFirst = #"(?:^|[.!?:;]\s*)i\s+(?:now\s+)?have\s+(?<count>"# + number + #")\s+(?:study\s+)?(?:sessions?|blocks?)\s+(?:of|with|lasting|for)\s+(?:only|at\s+most|up\s+to)\s+(?<duration>"# + number + #")\s*"# + unit + #"(?:\s+(?<qualifier>each|total))?"# + tail
    for (boundedPattern, boundedKind) in [(reverse, StudyPlanConstraintKind.totalMinutes), (countFirst, StudyPlanConstraintKind.minutesPerSession)] {
    if let expression = try? NSRegularExpression(pattern: boundedPattern, options: [.caseInsensitive]),
      let match = expression.firstMatch(in: question, range: NSRange(question.startIndex..., in: question)),
      let matchRange = Range(match.range, in: question),
      let countRange = Range(match.range(withName: "count"), in: question),
      let durationRange = Range(match.range(withName: "duration"), in: question),
      let tailRange = Range(match.range(withName: "tail"), in: question) {
      let outside = String(question[..<matchRange.lowerBound]) + " " + String(question[tailRange])
      let words = outside.lowercased().split { !$0.isLetter }.map(String.init)
      guard outside.allSatisfy({ $0.isLetter || $0.isWhitespace || ",.?!:;-’'".contains($0) }),
        words.allSatisfy({ !forbiddenTail.contains($0) }),
        !["can't", "don't", "won't", "couldn't", "wouldn't"].contains(where: outside.lowercased().contains)
      else { return nil }
      let countText = String(question[countRange]), durationText = String(question[durationRange])
      guard let count = groundedNumber(countText, in: question), (1...12).contains(count),
        let minutes = groundedNumber(durationText, in: question), (1...1440).contains(minutes),
        durationToken(durationText, unit: .minutes, in: question) else { return nil }
      let qualifier: String? = boundedKind == .minutesPerSession
        ? Range(match.range(withName: "qualifier"), in: question).map { question[$0].lowercased() } : nil
      guard boundedKind != .minutesPerSession || count == 1 || qualifier != nil else { return nil }
      let kind: StudyPlanConstraintKind = qualifier == "total" ? .totalMinutes : boundedKind
      guard kind != .totalMinutes || minutes >= count else { return nil }
      return [
        StudyPlanConstraint(kind: .sessionCount, relation: .exact, value: count, evidence: question, numberText: countText, unit: .count, origin: .currentQuestion),
        StudyPlanConstraint(kind: kind, relation: .maximum, value: minutes, evidence: question, numberText: durationText, unit: .minutes, origin: .currentQuestion),
      ]
    }
    }
    for pattern in patterns {
      guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
        let match = expression.firstMatch(in: question, range: NSRange(question.startIndex..., in: question)),
        let countRange = Range(match.range(withName: "count"), in: question),
        let durationRange = Range(match.range(withName: "duration"), in: question),
        let tailRange = Range(match.range(withName: "tail"), in: question)
      else { continue }
      let trailing = String(question[tailRange])
      // Reject extra explicit timing, negation and instruction terms. The independently
      // verified model path still checks the complete question and history.
      guard trailing.allSatisfy({ $0.isLetter || $0.isWhitespace || ",.?!:;-’'".contains($0) }) else { return nil }
      let normalized = trailing.lowercased().replacingOccurrences(of: "’", with: "'")
      guard !["can't", "don't", "won't", "isn't", "aren't", "shouldn't", "couldn't", "wouldn't"].contains(where: normalized.contains) else { return nil }
      let safeTail = normalized.replacingOccurrences(
        of: #"\b(?:new|updated|revised|current)\s+(?:time\s+)?(?:limit|budget|availability)\b"#,
        with: "", options: .regularExpression)
      let words = safeTail.split { !$0.isLetter }.map(String.init)
      guard words.allSatisfy({ !forbiddenTail.contains($0) }) else { return nil }
      let countText = String(question[countRange]), durationText = String(question[durationRange])
      guard let count = groundedNumber(countText, in: question), (1...12).contains(count),
        let minutes = groundedNumber(durationText, in: question), (1...1440).contains(minutes),
        durationToken(durationText, unit: .minutes, in: question)
      else { return nil }
      return [
        StudyPlanConstraint(kind: .sessionCount, relation: .exact, value: count, evidence: question, numberText: countText, unit: .count, origin: .currentQuestion),
        StudyPlanConstraint(kind: .minutesPerSession, relation: .exact, value: minutes, evidence: question, numberText: durationText, unit: .minutes, origin: .currentQuestion),
      ]
    }
    return nil
  }

  /// The semantic verifier must independently inspect the original questions and the complete
  /// proposed plan. Numeric grounding alone cannot establish that extraction was complete.
  @MainActor public static func validateVerified(
    constraints: [StudyPlanConstraint], availability: [StudyPlanAvailability] = [],
    sessions: [StudyPlanSession], currentQuestion: String, historyQuestions: [String],
    semanticCheck: @MainActor () async throws -> Bool,
    checkCurrent: @MainActor () throws -> Void
  ) async throws -> StudyPlanValidation {
    func check() throws { try Task.checkCancellation(); try checkCurrent() }
    try check()
    guard validate(constraints: constraints, availability: availability, sessions: sessions,
      currentQuestion: currentQuestion, historyQuestions: historyQuestions) == .valid
    else { return .clarify }
    let accepted: Bool
    do { accepted = try await semanticCheck() }
    catch { try check(); throw error }
    try check()
    return accepted ? .valid : .clarify
  }

  public static func validate(
    constraints: [StudyPlanConstraint], availability: [StudyPlanAvailability] = [],
    sessions: [StudyPlanSession], currentQuestion: String, historyQuestions: [String]
  ) -> StudyPlanValidation {
    func nonempty(_ value: String) -> Bool { !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    guard !sessions.isEmpty, sessions.allSatisfy({
      nonempty($0.day) && $0.minutes > 0 && $0.minutes <= 1440 && nonempty($0.task) && nonempty($0.check)
    }) else { return .clarify }
    func evidenceRank(_ evidence: String, _ origin: StudyPlanEvidenceOrigin) -> Int? {
      guard nonempty(evidence) else { return nil }
      switch origin {
      case .currentQuestion: return currentQuestion.contains(evidence) ? historyQuestions.count : nil
      case .history: return historyQuestions.lastIndex(where: { $0.contains(evidence) })
      }
    }
    guard let ranked = groundedConstraints(constraints, currentQuestion: currentQuestion, historyQuestions: historyQuestions) else { return .clarify }
    var total = 0
    var dayTotals: [String: Int] = [:]
    for (index, session) in sessions.enumerated() {
      let sum = total.addingReportingOverflow(session.minutes)
      guard !sum.overflow else { return .clarify }
      total = sum.partialValue
      let normalized = normalizedDay(session.day)
      let day = normalized == "unscheduled" ? "unscheduled-\(index)" : normalized
      let daily = dayTotals[day, default: 0].addingReportingOverflow(session.minutes)
      guard !daily.overflow, daily.partialValue <= 1440 else { return .clarify }
      dayTotals[day] = daily.partialValue
    }
    func accepts(_ actual: Int, _ constraint: StudyPlanConstraint) -> Bool {
      switch constraint.relation {
      case .exact: return actual == constraint.value
      case .maximum: return actual <= constraint.value
      case .minimum: return actual >= constraint.value
      }
    }
    for (constraint, rank) in ranked {
      guard rank == ranked.filter({ $0.0.kind == constraint.kind }).map(\.1).max() else { continue }
      switch constraint.kind {
      case .sessionCount: if !accepts(sessions.count, constraint) { return .clarify }
      case .minutesPerSession: if !sessions.allSatisfy({ accepts($0.minutes, constraint) }) { return .clarify }
      case .totalMinutes: if !accepts(total, constraint) { return .clarify }
      case .minutesPerDay:
        let weekdays = Set(["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"])
        guard dayTotals.keys.allSatisfy(weekdays.contains),
          dayTotals.values.allSatisfy({ accepts($0, constraint) })
        else { return .clarify }
      }
    }
    var rankedAvailability: [(StudyPlanAvailability, Int)] = []
    for item in availability {
      guard let rank = evidenceRank(item.evidence, item.origin), !item.days.isEmpty else { return .clarify }
      let days = item.days.map(normalizedDay)
      guard Set(days).count == days.count, days.allSatisfy({ isGroundedDay($0, evidence: item.evidence) }) else { return .clarify }
      rankedAvailability.append((item, rank))
    }
    if let latest = rankedAvailability.map(\.1).max() {
      for (item, rank) in rankedAvailability where rank == latest {
        let allowed = Set(item.days.map(normalizedDay))
        guard sessions.allSatisfy({ allowed.contains(normalizedDay($0.day)) }) else { return .clarify }
      }
    }
    return .valid
  }

  /// Drops only an ungrounded exact total that is algebraically forced by separately grounded
  /// exact session count and duration. Every other ungrounded constraint fails closed.
  public static func groundedPlanConstraints(
    _ constraints: [StudyPlanConstraint], currentQuestion: String, historyQuestions: [String]
  ) -> [StudyPlanConstraint]? {
    let grounded = constraints.filter {
      groundedConstraints([$0], currentQuestion: currentQuestion, historyQuestions: historyQuestions) != nil
    }
    if grounded.count == constraints.count { return constraints }
    guard let values = exactSlotValues(grounded, currentQuestion: currentQuestion, historyQuestions: historyQuestions) else { return nil }
    let product = values.count.multipliedReportingOverflow(by: values.minutes)
    guard !product.overflow else { return nil }
    for item in constraints where groundedConstraints([item], currentQuestion: currentQuestion, historyQuestions: historyQuestions) == nil {
      guard item.kind == .totalMinutes, item.relation == .exact, item.value == product.partialValue else { return nil }
    }
    return grounded
  }

  /// The model may fill only task and completion-check text for these trusted time slots.
  public static func authoritativeSlots(
    constraints: [StudyPlanConstraint], availability: [StudyPlanAvailability] = [],
    currentQuestion: String, historyQuestions: [String]
  ) -> [StudyPlanSlot]? {
    guard groundedAvailability(availability, currentQuestion: currentQuestion, historyQuestions: historyQuestions) == availability,
      let values = exactSlotValues(constraints, currentQuestion: currentQuestion, historyQuestions: historyQuestions),
      (1...12).contains(values.count), (1...1440).contains(values.minutes)
    else { return nil }
    var days: [String] = []
    if !availability.isEmpty {
      let ranked: [(StudyPlanAvailability, Int)] = availability.compactMap { item in
        switch item.origin {
        case .currentQuestion: return (item, historyQuestions.count)
        case .history: return historyQuestions.lastIndex(where: { $0.contains(item.evidence) }).map { (item, $0) }
        }
      }
      guard let latest = ranked.map(\.1).max(), let first = ranked.first(where: { $0.1 == latest })?.0 else { return nil }
      days = first.days.map(normalizedDay)
      for (item, rank) in ranked where rank == latest {
        let allowed = Set(item.days.map(normalizedDay))
        days = days.filter(allowed.contains)
      }
      guard !days.isEmpty else { return nil }
    }
    let slots = (0..<values.count).map { index in
      StudyPlanSlot(day: days.isEmpty ? "Unscheduled" : days[index % days.count].capitalized, minutes: values.minutes)
    }
    let candidate = slots.map { StudyPlanSession(day: $0.day, minutes: $0.minutes, task: "Task", check: "Check") }
    guard validate(constraints: constraints, availability: availability, sessions: candidate,
      currentQuestion: currentQuestion, historyQuestions: historyQuestions) == .valid
    else { return nil }
    return slots
  }

  /// Rejects missing, duplicate or unknown task indices and preserves authoritative slot order.
  public static func compose(slots: [StudyPlanSlot], fills: [StudyPlanTaskFill]) -> [StudyPlanSession]? {
    guard !slots.isEmpty, fills.count == slots.count else { return nil }
    let indices = Set(fills.map(\.slotIndex))
    guard indices.count == fills.count, indices == Set(1...slots.count), fills.allSatisfy({
      !$0.task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !$0.check.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }) else { return nil }
    let indexed = Dictionary(uniqueKeysWithValues: fills.map { ($0.slotIndex, $0) })
    var result: [StudyPlanSession] = []
    for (index, slot) in slots.enumerated() {
      guard let fill = indexed[index + 1], !slot.day.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        (1...1440).contains(slot.minutes) else { return nil }
      result.append(StudyPlanSession(day: slot.day, minutes: slot.minutes, task: fill.task, check: fill.check))
    }
    return result
  }

  private static func exactSlotValues(
    _ constraints: [StudyPlanConstraint], currentQuestion: String, historyQuestions: [String]
  ) -> (count: Int, minutes: Int)? {
    guard let ranked = groundedConstraints(constraints, currentQuestion: currentQuestion, historyQuestions: historyQuestions) else { return nil }
    func exactValue(_ kind: StudyPlanConstraintKind) -> Int? {
      let matching = ranked.filter { $0.0.kind == kind }
      guard let latest = matching.map(\.1).max() else { return nil }
      let values = Set(matching.filter { $0.1 == latest && $0.0.relation == .exact }.map { $0.0.value })
      return values.count == 1 ? values.first : nil
    }
    guard let count = exactValue(.sessionCount), count > 0 else { return nil }
    if let minutes = exactValue(.minutesPerSession) { return (count, minutes) }
    let perSession = ranked.filter { $0.0.kind == .minutesPerSession }
    if let latest = perSession.map(\.1).max(),
      let maximum = perSession.filter({ $0.1 == latest && $0.0.relation == .maximum }).map({ $0.0.value }).min() {
      return (count, maximum)
    }
    let totals = ranked.filter { $0.0.kind == .totalMinutes }
    guard let latest = totals.map(\.1).max() else { return nil }
    let upper = totals.filter { $0.1 == latest && ($0.0.relation == .maximum || $0.0.relation == .exact) }.map { $0.0.value }
    guard let total = upper.min(), total >= count else { return nil }
    return (count, total / count)
  }

  /// Checks exact numeric and unit grounding before the plan-writing model is called.
  /// A separate semantic verifier must still check for missing or misinterpreted constraints.
  public static func constraintsAreGrounded(
    _ constraints: [StudyPlanConstraint], currentQuestion: String, historyQuestions: [String]
  ) -> Bool {
    groundedConstraints(constraints, currentQuestion: currentQuestion, historyQuestions: historyQuestions) != nil
  }

  /// Filters ungrounded candidate availability before plan drafting. The caller must still
  /// independently verify the complete original questions for omitted or misread constraints.
  public static func groundedAvailability(
    _ availability: [StudyPlanAvailability], currentQuestion: String, historyQuestions: [String]
  ) -> [StudyPlanAvailability] {
    availability.filter { item in
      guard !item.evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        !item.days.isEmpty else { return false }
      let present: Bool
      switch item.origin {
      case .currentQuestion: present = currentQuestion.contains(item.evidence)
      case .history: present = historyQuestions.contains { $0.contains(item.evidence) }
      }
      let days = item.days.map(normalizedDay)
      return present && Set(days).count == days.count
        && days.allSatisfy { isGroundedDay($0, evidence: item.evidence) }
    }
  }

  /// Reports only a conflict derivable from explicitly grounded minimum requirements.
  public static func conflictMessage(
    constraints: [StudyPlanConstraint], currentQuestion: String, historyQuestions: [String]
  ) -> String? {
    guard let ranked = groundedConstraints(constraints, currentQuestion: currentQuestion, historyQuestions: historyQuestions) else { return nil }
    func active(_ kind: StudyPlanConstraintKind) -> [StudyPlanConstraint] {
      let matching = ranked.filter { $0.0.kind == kind }
      guard let latest = matching.map(\.1).max() else { return [] }
      return matching.filter { $0.1 == latest }.map(\.0)
    }
    guard let count = active(.sessionCount).filter({ $0.relation != .maximum }).map(\.value).max(),
      let minutes = active(.minutesPerSession).filter({ $0.relation != .maximum }).map(\.value).max(),
      let total = active(.totalMinutes).filter({ $0.relation != .minimum }).map(\.value).min()
    else { return nil }
    let product = count.multipliedReportingOverflow(by: minutes)
    guard !product.overflow, product.partialValue > total else { return nil }
    return "If I understand your limits correctly, these requirements need at least \(product.partialValue) minutes, but the available total is \(total) minutes. The plan would need fewer sessions, shorter sessions, or more total time."
  }

  private static func groundedConstraints(
    _ constraints: [StudyPlanConstraint], currentQuestion: String, historyQuestions: [String]
  ) -> [(StudyPlanConstraint, Int)]? {
    var result: [(StudyPlanConstraint, Int)] = []
    for constraint in constraints {
      guard !constraint.evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
      let rank: Int?
      switch constraint.origin {
      case .currentQuestion: rank = currentQuestion.contains(constraint.evidence) ? historyQuestions.count : nil
      case .history: rank = historyQuestions.lastIndex(where: { $0.contains(constraint.evidence) })
      }
      guard let rank, constraint.value > 0,
        let number = groundedNumber(constraint.numberText, in: constraint.evidence), number > 0
      else { return nil }
      switch (constraint.kind, constraint.unit) {
      case (.sessionCount, .count):
        guard number == constraint.value else { return nil }
      case (.minutesPerSession, .minutes), (.totalMinutes, .minutes), (.minutesPerDay, .minutes):
        guard number == constraint.value, durationToken(constraint.numberText, unit: .minutes, in: constraint.evidence) else { return nil }
      case (.minutesPerSession, .hours), (.totalMinutes, .hours), (.minutesPerDay, .hours):
        guard durationToken(constraint.numberText, unit: .hours, in: constraint.evidence) else { return nil }
        let product = number.multipliedReportingOverflow(by: 60)
        guard !product.overflow, product.partialValue == constraint.value else { return nil }
      default: return nil
      }
      result.append((constraint, rank))
    }
    return result
  }

  private static func normalizedDay(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }
  private static func isGroundedDay(_ day: String, evidence: String) -> Bool {
    let weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday"]
    let weekends = ["saturday", "sunday"]
    guard (weekdays + weekends).contains(day) else { return false }
    return containsWholeToken(day, in: evidence)
      || (weekdays.contains(day) && containsWholeToken("weekdays", in: evidence))
      || (weekends.contains(day) && containsWholeToken("weekends", in: evidence))
  }
  private static func groundedNumber(_ token: String, in evidence: String) -> Int? {
    let clean = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !clean.isEmpty, containsWholeToken(clean, in: evidence) else { return nil }
    if let value = Int(clean) { return value }
    let small = ["zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19]
    let tens = ["twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90]
    if let value = small[clean] ?? tens[clean] { return value }
    let parts = clean.replacingOccurrences(of: "-", with: " ").split(separator: " ").map(String.init)
    guard parts.count == 2, let first = tens[parts[0]], let second = small[parts[1]], (1...9).contains(second) else { return nil }
    return first + second
  }
  private static func durationToken(_ token: String, unit: StudyPlanUnit, in evidence: String) -> Bool {
    let clean = token.trimmingCharacters(in: .whitespacesAndNewlines)
    let units: String
    switch unit {
    case .minutes: units = "(?:minutes?|mins?|m)"
    case .hours: units = "(?:hours?|hrs?|h)"
    case .count: return false
    }
    let prefix = clean.allSatisfy(\.isNumber) ? #"(?<![0-9.,])"# : #"(?<![\p{L}])"#
    let pattern = prefix + NSRegularExpression.escapedPattern(for: clean)
      + #"\s*(?:-\s*)?"# + units + #"(?![\p{L}])"#
    let range = NSRange(evidence.startIndex..., in: evidence)
    guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
    if expression.firstMatch(in: evidence, range: range) != nil { return true }
    // A range may share its unit, as in "20 to 30 minutes" or "20-30 minutes".
    let rangeEnd = #"(?:[0-9]+|[\p{L}]+(?:[ -][\p{L}]+)?)"#
    let rangePattern = prefix + NSRegularExpression.escapedPattern(for: clean)
      + #"\s*(?:to|through|-)\s*"# + rangeEnd + #"\s*(?:-\s*)?"# + units + #"(?![\p{L}])"#
    guard let rangeExpression = try? NSRegularExpression(pattern: rangePattern, options: [.caseInsensitive]) else { return false }
    return rangeExpression.firstMatch(in: evidence, range: range) != nil
  }
  private static func containsWholeToken(_ token: String, in evidence: String) -> Bool {
    let lower = evidence.lowercased()
    let numeric = token.allSatisfy(\.isNumber)
    var searchStart = lower.startIndex
    while searchStart < lower.endIndex,
      let range = lower.range(of: token, range: searchStart..<lower.endIndex)
    {
      let before = range.lowerBound > lower.startIndex ? lower[lower.index(before: range.lowerBound)] : nil
      let after = range.upperBound < lower.endIndex ? lower[range.upperBound] : nil
      func blocks(_ value: Character?) -> Bool {
        guard let value else { return false }
        return numeric ? value.isNumber || value == "." || value == "," : value.isLetter
      }
      if !blocks(before) && !blocks(after) { return true }
      searchStart = range.upperBound
    }
    return false
  }
}
