import XCTest
@testable import UniCoachCore

final class LongContextTests: XCTestCase {
  @MainActor func testDirectRequestKeepsExactInput() async throws {
    let result = try await LongContextProcessor.prepare(
      instructions: "instructions", prompt: "question 😊", responseBudget: 70, currentQuestion: "question 😊",
      fits: { _, _, budget, final in XCTAssertEqual(budget, 70); XCTAssertTrue(final); return true },
      generate: { _, _, _ in XCTFail("No summary should be generated"); return "" },
      checkCurrent: {})
    XCTAssertEqual(result.instructions, "instructions")
    XCTAssertEqual(result.prompt, "question 😊")
    XCTAssertNil(result.notes)
    XCTAssertTrue(result.steps.isEmpty)
  }

  @MainActor func testEveryUnicodeCharacterIsCoveredWithoutTruncation() async throws {
    let original = String(repeating: "👨‍👩‍👧‍👦 café\n", count: 500)
    let result = try await LongContextProcessor.prepare(
      instructions: "original instructions", prompt: original, responseBudget: 100,
      fits: { _, text, _, final in final ? text.count < 220 : text.count <= 300 },
      generate: { _, _, _ in "brief note" }, checkCurrent: {})
    let chunks = result.steps.filter { $0.kind == .chunk }
    XCTAssertEqual(chunks.map(\.prompt).joined(), original)
    let utf16 = original as NSString
    var offset = 0
    for step in chunks {
      let range = try XCTUnwrap(step.provenance.first)
      XCTAssertEqual(range.location, offset)
      XCTAssertEqual(utf16.substring(with: NSRange(location: range.location, length: range.length)), step.prompt)
      offset += range.length
    }
    XCTAssertEqual(offset, utf16.length)
    XCTAssertNotNil(result.notes)
    let encoded = try JSONEncoder().encode(result.steps)
    XCTAssertEqual(try JSONDecoder().decode([ModelProcessingStep].self, from: encoded), result.steps)
  }

  @MainActor func testLongSourcesPreserveExactCurrentQuestionInFinalPrompt() async throws {
    let question = "How can I improve this argument?  😊"
    let original = "Question:\n\(question)\n\nSource:\n" + String(repeating: "long source ", count: 500)
    let result = try await LongContextProcessor.prepare(
      instructions: "i", prompt: original, responseBudget: 100, currentQuestion: question,
      fits: { _, p, _, final in final ? p.count < 400 : p.count <= 1000 },
      generate: { _, _, _ in "Concise note" }, checkCurrent: {})
    XCTAssertNotNil(result.notes)
    XCTAssertTrue(result.prompt.hasPrefix("Current question:\n\(question)\n\n"))
    XCTAssertEqual(result.steps.filter { $0.kind == .chunk }.map(\.prompt).joined(), original)
  }

  @MainActor func testAdjustedChunkIsRecheckedWhenFitIsNonMonotonic() async throws {
    let input = "abc\ndefghijklmnop"
    let result = try await LongContextProcessor.prepare(
      instructions: "i", prompt: input, responseBudget: 1,
      fits: { _, p, _, final in final ? p.count > input.count : p.count <= 8 && !p.hasSuffix("\n") },
      generate: { _, p, _ in
        XCTAssertLessThanOrEqual(p.count, 8)
        XCTAssertFalse(p.hasSuffix("\n"))
        return "n"
      }, checkCurrent: {})
    XCTAssertEqual(result.steps.filter { $0.kind == .chunk }.map(\.prompt).joined(), input)
  }

  @MainActor func testImpossibleFitAndNonShrinkingSummariesFailExplicitly() async throws {
    do {
      _ = try await LongContextProcessor.prepare(instructions: "i", prompt: "a", responseBudget: 1,
        fits: { _, _, _, _ in false }, generate: { _, _, _ in "x" }, checkCurrent: {})
      XCTFail("A character that cannot fit must fail")
    } catch { XCTAssertEqual(error as? UniCoachError, .contextProcessingFailed) }
    do {
      _ = try await LongContextProcessor.prepare(instructions: "i", prompt: String(repeating: "a", count: 600), responseBudget: 1,
        fits: { _, p, _, final in !final && p.count <= 300 },
        generate: { _, p, _ in p }, checkCurrent: {})
      XCTFail("Non-shrinking notes must fail")
    } catch { XCTAssertEqual(error as? UniCoachError, .contextProcessingFailed) }
  }

  @MainActor func testCancellationDuringFitAndGenerationIsCheckedAfterAwait() async throws {
    var valid = true
    do {
      _ = try await LongContextProcessor.prepare(instructions: "i", prompt: "some material", responseBudget: 1,
        fits: { _, _, _, _ in valid = false; return true }, generate: { _, _, _ in "unused" },
        checkCurrent: { if !valid { throw UniCoachError.cancelled } })
      XCTFail("Cancelled fit must fail")
    } catch { XCTAssertEqual(error as? UniCoachError, .cancelled) }
    valid = true
    do {
      _ = try await LongContextProcessor.prepare(instructions: "i", prompt: "some material", responseBudget: 1,
        fits: { _, _, _, final in !final }, generate: { _, _, _ in valid = false; return "late" },
        checkCurrent: { if !valid { throw UniCoachError.sourceChanged } })
      XCTFail("Stale generation must fail")
    } catch { XCTAssertEqual(error as? UniCoachError, .sourceChanged) }
  }

  @MainActor func testInitiallyStaleRequestConsumesTicketBeforeGeneration() async throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let store = UniCoachStore(fileURL: url)
    try store.saveProfile(.init(name: "Synthetic"))
    var draft = ConsentDraft(question: "Question", engine: .appleOnDevice, purpose: .mentorQuestion)
    draft.setSelected(true, source: try XCTUnwrap(store.contextSources().first { $0.id == "profile" }))
    let request = try store.approve(draft: draft)
    let ticket = try store.beginGeneration(for: request)
    try store.saveProfile(.init(name: "Changed"))
    do {
      _ = try await store.generateProcessedMentorAnswer(request: request, ticket: ticket) { _ in
        XCTFail("Stale request reached generator")
        return MentorGenerationResult(answer: "Unused", steps: [])
      }
      XCTFail("Expected stale request")
    } catch { XCTAssertEqual(error as? UniCoachError, .sourceChanged) }
    do {
      _ = try await store.generateProcessedMentorAnswer(request: request, ticket: ticket) { _ in
        XCTFail("Consumed ticket reached generator")
        return MentorGenerationResult(answer: "Unused", steps: [])
      }
      XCTFail("Expected consumed ticket")
    } catch { XCTAssertEqual(error as? UniCoachError, .cancelled) }
  }

  @MainActor func testInitiallyCancelledTaskConsumesTicketBeforeGeneration() async throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let store = UniCoachStore(fileURL: url)
    let request = try store.approve(draft: ConsentDraft(question: "Question", engine: .appleOnDevice, purpose: .mentorQuestion))
    let ticket = try store.beginGeneration(for: request)
    let task = Task { @MainActor in
      withUnsafeCurrentTask { $0?.cancel() }
      do {
        _ = try await store.generateProcessedMentorAnswer(request: request, ticket: ticket) { _ in
          XCTFail("Cancelled task reached generator")
          return MentorGenerationResult(answer: "Unused", steps: [])
        }
        XCTFail("Expected cancellation")
      } catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
    }
    await task.value
    do {
      _ = try await store.generateProcessedMentorAnswer(request: request, ticket: ticket) { _ in
        XCTFail("Consumed ticket reached generator")
        return MentorGenerationResult(answer: "Unused", steps: [])
      }
      XCTFail("Expected consumed ticket")
    } catch { XCTAssertEqual(error as? UniCoachError, .cancelled) }
  }

  @MainActor func testDeletingConversationDuringProcessingPreventsSave() async throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let store = UniCoachStore(fileURL: url)
    let rootRequest = try store.approve(draft: ConsentDraft(question: "Root", engine: .appleOnDevice, purpose: .mentorQuestion))
    let root = try await store.generateMentorAnswer(request: rootRequest, ticket: store.beginGeneration(for: rootRequest)) { _ in "Answer" }
    let snapshot = try store.conversationSnapshot(id: root.id)
    let draft = ConsentDraft(question: String(repeating: "x", count: 1000), engine: .appleOnDevice, purpose: .mentorQuestion, conversation: snapshot)
    let request = try store.approve(draft: draft)
    let ticket = try store.beginGeneration(for: request)
    do {
      _ = try await store.generateProcessedMentorAnswer(request: request, ticket: ticket) { input in
        _ = try await LongContextProcessor.prepare(instructions: input.instructions, prompt: input.prompt, responseBudget: 100,
          fits: { _, _, _, final in !final },
          generate: { _, _, _ in try store.deleteMentorConversation(id: root.id); return "late" },
          checkCurrent: { try store.validateGeneration(request: request, ticket: ticket) })
        return MentorGenerationResult(answer: "late", steps: [])
      }
      XCTFail("Deleted thread must not return")
    } catch { XCTAssertEqual(error as? UniCoachError, .sourceChanged) }
    XCTAssertTrue(store.conversationAnswers(id: root.id).isEmpty)
  }
  @MainActor func testFiftyThousandCharacterBoundaryIncludesHistoryAndSource() async throws {
    XCTAssertEqual(UniCoachStore.contextCharacterLimit, 50_000)
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let store = UniCoachStore(fileURL: url)
    try store.saveProfile(.init(name: "Synthetic"))
    let rootRequest = try store.approve(draft: ConsentDraft(question: "Root", engine: .appleOnDevice, purpose: .mentorQuestion))
    let root = try await store.generateMentorAnswer(request: rootRequest, ticket: store.beginGeneration(for: rootRequest)) { _ in "Answer" }
    let history = try store.conversationSnapshot(id: root.id)
    let source = try XCTUnwrap(store.contextSources().first { $0.id == "profile" })
    var draft = ConsentDraft(question: "Q", engine: .appleOnDevice, purpose: .mentorQuestion, conversation: history)
    draft.setSelected(true, source: source)
    draft.setText(String(repeating: "s", count: 50_000 - history.transcript.count - 1), sourceID: source.id)
    _ = try store.approve(draft: draft)
    draft.question += "x"
    XCTAssertThrowsError(try store.approve(draft: draft)) { XCTAssertEqual($0 as? UniCoachError, .contextTooLong) }
    let questionOnly = ConsentDraft(question: String(repeating: "q", count: 50_000), engine: .appleOnDevice, purpose: .mentorQuestion)
    let request = try store.approve(draft: questionOnly)
    let ticket = try store.beginGeneration(for: request)
    let saved = try await store.generateProcessedMentorAnswer(request: request, ticket: ticket) { input in
      let prepared = try await LongContextProcessor.prepare(instructions: input.instructions, prompt: input.prompt, responseBudget: 100, currentQuestion: input.currentQuestion,
        fits: { _, prompt, _, final in final ? prompt.count < 500 : prompt.count <= 2000 },
        generate: { _, _, _ in "Short note" },
        checkCurrent: { try store.validateGeneration(request: request, ticket: ticket) })
      XCTAssertEqual(prepared.steps.filter { $0.kind == .chunk }.map(\.prompt).joined(), input.prompt)
      XCTAssertFalse(prepared.prompt.contains(input.currentQuestion))
      let final = ModelProcessingStep(kind: .final, instructions: prepared.instructions, prompt: prepared.prompt, output: "Answer", responseBudget: 100)
      return MentorGenerationResult(answer: "Answer", steps: prepared.steps + [final])
    }
    XCTAssertEqual(saved.question.count, 50_000)
    XCTAssertEqual(saved.processingSteps?.last?.kind, .final)
    let restored = UniCoachStore(fileURL: url)
    XCTAssertEqual(restored.data.mentorAnswers.first?.processingSteps, saved.processingSteps)
    XCTAssertTrue(saved.promptSnapshot.contains(request.question))
  }

  @MainActor func testReportProcessingAuditPersistsAlongsideOriginalPrompt() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let store = UniCoachStore(fileURL: url)
    try store.saveProfile(.init(name: "Synthetic"))
    var draft = ConsentDraft()
    draft.setSelected(true, source: try XCTUnwrap(store.contextSources().first { $0.id == "profile" }))
    let request = try store.approve(draft: draft)
    let ticket = try store.beginGeneration(for: request)
    let step = ModelProcessingStep(kind: .final, instructions: "i", prompt: "p", output: "o", responseBudget: 70, schemaSnapshot: "schema")
    let report = try store.saveReport(request: request, output: store.generateOffline(request: request), ticket: ticket, promptSnapshots: ["original"], processingSteps: [step])
    XCTAssertEqual(report.processingSteps, [step])
    let restored = UniCoachStore(fileURL: url).data.reports.first
    XCTAssertEqual(restored?.processingSteps, [step])
    XCTAssertEqual(restored?.promptSnapshots, ["original"])
  }

  func testLegacyAnswerAndReportDecodeWithoutProcessingSteps() throws {
    let step = ModelProcessingStep(kind: .final, instructions: "i", prompt: "p", output: "o", responseBudget: 100, schemaSnapshot: "schema")
    let report = MentorReport(question: "q", engine: .contextualOffline, sources: [], output: .init(summary: "s", recommendations: [], evidenceSourceIDs: []), processingSteps: [step])
    let roundTrip = try JSONDecoder().decode(MentorReport.self, from: JSONEncoder().encode(report))
    XCTAssertEqual(roundTrip.processingSteps, [step])
    var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(report)) as? [String: Any])
    json.removeValue(forKey: "processingSteps")
    let legacy = try JSONDecoder().decode(MentorReport.self, from: JSONSerialization.data(withJSONObject: json))
    XCTAssertNil(legacy.processingSteps)
  }

}
