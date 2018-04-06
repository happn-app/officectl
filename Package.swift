// swift-tools-version:4.0
import PackageDescription

let package = Package(
	name: "ghapp",
	dependencies: [
		.package(url: "https://github.com/klaas/Guaka.git", from: "0.3.0")
	],
	targets: [
		.target(name: "ghapp", dependencies: ["Guaka"]),
	]	
)
