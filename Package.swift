// swift-tools-version:4.2
import PackageDescription


let package = Package(
	name: "officectl",
	dependencies: [
		.package(url: "https://github.com/happn-tech/AsyncOperationResult.git", from: "1.0.4"),
		.package(url: "https://github.com/happn-tech/URLRequestOperation.git", from: "1.1.2"),
		.package(url: "https://github.com/happn-tech/RetryingOperation.git", from: "1.1.1"),
		.package(url: "https://github.com/happn-tech/SemiSingleton.git", from: "2.0.0"),
		.package(url: "git@github.com:happn-app/Swift-OpenLDAP.git", from: "1.0.0"),
		.package(url: "git@github.com:happn-app/Swift-CommonCrypto.git", from: "1.0.0"),
		.package(url: "https://github.com/apple/swift-nio.git", from: "1.8.0"),
		.package(url: "https://github.com/klaas/Guaka.git", from: "0.3.0"),
		.package(url: "https://github.com/vapor/leaf.git", from: "3.0.0"),
		.package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
		.package(url: "https://github.com/vapor/crypto.git", from: "3.0.0"),
		.package(url: "https://github.com/vapor/fluent-sqlite.git", from: "3.0.0"),
		.package(url: "https://github.com/behrang/YamlSwift.git", from: "3.0.0"),
		.package(url: "https://github.com/vapor/jwt.git", from: "3.0.0")
	],
	targets: [
		.target(name: "OfficeKit", dependencies: ["AsyncOperationResult", "RetryingOperation", "URLRequestOperation", "SemiSingleton", "NIO", "FluentSQLite", "Crypto", "Vapor", "JWT"]),
		.target(name: "officectl", dependencies: ["OfficeKit", "Vapor", "Leaf", "Guaka", "Yaml", "JWT"]),
		.testTarget(name: "OfficeKitTests", dependencies: ["OfficeKit"])
	]	
)
