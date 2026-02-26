// swift-tools-version: 6.2

import PackageDescription

let package = Package(
	name: "Lock",
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
			name: "Lock",
			targets: ["Lock"]),
	],
	targets: [
		.target(
			name: "Lock",
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
			]
		),
		.testTarget(
			name: "LockTests",
			dependencies: ["Lock"],
			swiftSettings: [
				.enableUpcomingFeature("NonisolatedNonsendingByDefault"),
			]
		),
	]
)
