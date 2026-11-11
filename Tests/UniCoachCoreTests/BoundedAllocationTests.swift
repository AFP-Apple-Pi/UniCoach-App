import XCTest
@testable import UniCoachCore

final class BoundedAllocationTests: XCTestCase {
  func testDurationFirstAndCountFirstRespectMaximums() throws {
    let examples: [(String, [Int])] = [
      ("Back to the campus report: I now have only 20 minutes in one session. Give me a revision plan that fits, prioritising the evidence behind the power-access requirement.", [20]),
      ("I have at most 60 minutes across three sessions.", [20, 20, 20]),
      ("I have two sessions of up to 25 minutes each.", [25, 25]),
      ("I have one session with at most 20 minutes total.", [20]),
      ("I have three sessions of up to one minute each.", [1, 1, 1]),
    ]
    let history = ["How did I do on this report?", "Turn that into three revision steps.", "Explain what to keep and change for statistics."]
    for (question, durations) in examples {
      guard case .explicit(let constraints) = StudyPlanValidator.explicitAllocationRoute(currentQuestion: question, historyQuestions: history) else { return XCTFail(question) }
      XCTAssertEqual(constraints[1].relation, .maximum)
      XCTAssertTrue(constraints.allSatisfy { $0.evidence == question && $0.origin == .currentQuestion })
      XCTAssertEqual(StudyPlanValidator.authoritativeSlots(constraints: constraints, currentQuestion: question, historyQuestions: history)?.map(\.minutes), durations)
    }
  }
  func testAdditionalOrPriorLimitsRequireVerification() {
    for question in ["I have only 20 minutes in one session on Monday.", "I have at most 60 minutes across three sessions plus 10 minutes of breaks.", "I have two sessions with at most 20 minutes."] {
      XCTAssertEqual(StudyPlanValidator.explicitAllocationRoute(currentQuestion: question, historyQuestions: []), .needsVerifiedPlan)
    }
    let q = "I have only 20 minutes in one session."
    XCTAssertEqual(StudyPlanValidator.explicitAllocationRoute(currentQuestion: q, historyQuestions: ["I can only study on Monday."]), .needsVerifiedPlan)
  }
}
