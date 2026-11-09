// swift-tools-version: 5.9
import PackageDescription

let package = Package(name: "UniCoach", platforms: [.iOS(.v17), .macOS(.v14)], products: [.library(name: "UniCoachCore", targets: ["UniCoachCore"])], targets: [.target(name: "UniCoachCore"), .testTarget(name: "UniCoachCoreTests", dependencies: ["UniCoachCore"])])
