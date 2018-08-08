// swift-tools-version:4.0
import PackageDescription


let package = Package(
	name: "officectl",
	dependencies: [
		.package(url: "git@github.com:happn-app/AsyncOperationResult.git", from: "1.0.4"),
		.package(url: "git@github.com:happn-app/URLRequestOperation.git", from: "1.1.2"),
		.package(url: "git@github.com:happn-app/RetryingOperation.git", from: "1.1.1"),
		.package(url: "git@github.com:happn-app/Swift-OpenLDAP.git", from: "1.0.0"),
		.package(url: "git@github.com:happn-app/Swift-CommonCrypto.git", from: "1.0.0"),
		.package(url: "https://github.com/apple/swift-nio.git", from: "1.8.0"),
		.package(url: "https://github.com/klaas/Guaka.git", from: "0.3.0"),
		.package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
		.package(url: "https://github.com/vapor/crypto.git", from: "3.0.0"),
		.package(url: "https://github.com/vapor/fluent-sqlite.git", from: "3.0.0")
	],
	targets: [
		.target(name: "OfficeKit", dependencies: ["AsyncOperationResult", "RetryingOperation", "URLRequestOperation", "NIO", "FluentSQLite", "Crypto", "Vapor"]),
		.target(name: "officectl", dependencies: ["OfficeKit", "Vapor", "Guaka"]),
		.testTarget(name: "OfficeKitTests", dependencies: ["OfficeKit"])
	]	
)
