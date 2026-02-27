// swift-tools-version: 6.2

import PackageDescription

let package = Package(
	name: "TaskGate",
	platforms: [
		.macOS(.v10_15),
		.macCatalyst(.v13),
		.iOS(.v13),
		.tvOS(.v13),
		.visionOS(.v1),
		.watchOS(.v6),
	],
	products: [
		.library(
			name: "Gate",
			targets: ["Gate"]),
	],
	targets: [
		.target(
			name: "Gate",
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
			]
		),
		.testTarget(
			name: "GateTests",
			dependencies: ["Gate"],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
			]
		),
	]
)
