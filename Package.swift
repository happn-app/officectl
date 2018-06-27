// swift-tools-version:4.0
import PackageDescription


let package = Package(
	name: "officectl",
	dependencies: [
		.package(url: "git@github.com:happn-app/AsyncOperationResult.git", from: "1.0.0"),
		.package(url: "git@github.com:happn-app/URLRequestOperation.git", from: "1.0.0"),
		.package(url: "git@github.com:happn-app/RetryingOperation.git", from: "1.0.0"),
		.package(url: "https://github.com/klaas/Guaka.git", from: "0.3.0"),
		.package(url: "https://github.com/venj/CommonCrypto.git", from: "0.3.0")
	],
	targets: [
		.target(name: "officectl", dependencies: ["Guaka", "AsyncOperationResult", "RetryingOperation", "URLRequestOperation", "CommonCrypto"])
	]	
)
