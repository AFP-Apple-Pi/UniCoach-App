import Foundation

public struct DocumentImportPage: Codable, Equatable {
  public var number: Int
  public var text: String
  public var method: String
  public init(number: Int, text: String, method: String = "text") {
    self.number = number; self.text = text; self.method = method
  }
}

public struct DocumentSourceReference: Codable, Equatable {
  public var filename: String
  public var pageNumbers: [Int]
  public var text: String
  public init(filename: String, pageNumbers: [Int], text: String) {
    self.filename = filename; self.pageNumbers = pageNumbers; self.text = text
  }
}

public struct DocumentImportDraft {
  public var subject: Subject
  public var assignments: [Assignment]
  public var pages: [DocumentImportPage]
  public var sourceName: String
  public init(subject: Subject, assignments: [Assignment], pages: [DocumentImportPage], sourceName: String) {
    self.subject = subject; self.assignments = assignments; self.pages = pages; self.sourceName = sourceName
  }
}

public enum DocumentImportParser {
  private static func matches(_ pattern: String, in text: String) -> [NSTextCheckingResult] {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines]) else { return [] }
    return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
  }
  private static func group(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> String {
    guard index < match.numberOfRanges, let range = Range(match.range(at: index), in: text) else { return "" }
    return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
  }
  private static func first(_ pattern: String, in text: String) -> String {
    guard let match = matches(pattern, in: text).first else { return "" }
    return group(match, 1, in: text)
  }
  public static func parse(sourceName: String, pages: [DocumentImportPage]) -> DocumentImportDraft {
    let ordered = pages.sorted { $0.number < $1.number }
    let cleaned = ordered.map { page in
      page.text.replacingOccurrences(of: "(?im)^Generated [^\\n]* Page [0-9]+\\s*/\\s*[0-9]+\\s*$", with: "", options: .regularExpression)
    }
    let text = cleaned.joined(separator: "\n")
    let ns = text as NSString
    let subjectMatch = matches("^([0-9]{4,8})[ \\t]+([^\\n]+(?:\\n(?!Delivery:|Credit Points:|Subject Description)[^\\n:]+)?)", in: text).first
    let code = subjectMatch.map { group($0, 1, in: text) } ?? ""
    let name = (subjectMatch.map { group($0, 2, in: text) } ?? "").replacingOccurrences(of: "\n", with: " ")
    let semester = first("^Delivery:[ \\t]*([^\\n]+)", in: text)
    let credits = Double(first("^Credit Points:[ \\t]*([0-9]+(?:\\.[0-9]+)?)", in: text)) ?? 0
    let description = first("(?s)Subject Description\\s*\\n(.*?)(?:\\nSubject Learning Outcomes|\\nTeaching and Learning Strategies|\\nAssessment task|$)", in: text)
    var subject = Subject(code: code, name: name, credits: credits, semester: semester.isEmpty ? nil : semester, description: description)
    if let firstPage = ordered.first {
      subject.sourceReferences = [DocumentSourceReference(filename: sourceName, pageNumbers: [firstPage.number], text: firstPage.text)]
    }
    let headings = matches("^Assessment task[ \\t]+[0-9]+:[ \\t]*([^\\n]+(?:\\n(?!Description:|Learning Outcomes:|Type:)[^\\n:]+)?)", in: text)
    var assignments: [Assignment] = []
    for (index, heading) in headings.enumerated() {
      let next = index + 1 < headings.count ? headings[index + 1].range.location : ns.length
      let tail = ns.substring(with: NSRange(location: heading.range.location, length: next - heading.range.location))
      let terminator = matches("^Academic Integrity\\s*$", in: tail).first?.range.location ?? (tail as NSString).length
      let end = heading.range.location + terminator
      let section = ns.substring(with: NSRange(location: heading.range.location, length: end - heading.range.location))
      let rawTitle = group(heading, 1, in: text).replacingOccurrences(of: "\n", with: " ")
      let type = first("^Type:[ \\t]*([^\\n]+)", in: section)
      let groupworkText = first("^Groupwork:[ \\t]*([^\\n]+)", in: section)
      let groupwork = groupworkText.lowercased().hasPrefix("group") ? "Group" : (groupworkText.lowercased().hasPrefix("individual") ? "Individual" : groupworkText)
      let weight = Double(first("^Weight:[ \\t]*([0-9]+(?:\\.[0-9]+)?)%", in: section))
      let iso = first("^Due:[ \\t]*([0-9]{4}-[0-9]{2}-[0-9]{2})", in: section)
      let parts = iso.split(separator: "-").compactMap { Int($0) }
      let date = parts.count == 3 ? Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) : nil
      var assignment = Assignment(subjectID: subject.id, title: rawTitle, brief: section.trimmingCharacters(in: .whitespacesAndNewlines), dueDate: date, collaborationType: groupwork, assignmentFormat: type, weighting: weight)
      var offset = 0
      var included: [Int] = []
      for (page, pageText) in zip(ordered, cleaned) {
        let pageRange = NSRange(location: offset, length: (pageText as NSString).length)
        if NSIntersectionRange(pageRange, NSRange(location: heading.range.location, length: end - heading.range.location)).length > 0 { included.append(page.number) }
        offset += pageRange.length + 1
      }
      assignment.sourceReferences = [DocumentSourceReference(filename: sourceName, pageNumbers: included, text: section)]
      assignments.append(assignment)
    }
    return DocumentImportDraft(subject: subject, assignments: assignments, pages: ordered, sourceName: sourceName)
  }
}
