// swift-tools-version:5.0
import PackageDescription


let package = Package(
	name: "officectl",
	platforms: [
		.macOS(.v10_13)
	],
	dependencies: [
		.package(url: "https://github.com/happn-tech/URLRequestOperation.git", from: "1.1.2"),
		.package(url: "https://github.com/happn-tech/RetryingOperation.git", from: "1.1.1"),
		.package(url: "https://github.com/happn-tech/SemiSingleton.git", from: "2.0.0"),
		.package(url: "https://github.com/apple/swift-nio.git", from: "1.8.0"),
		.package(url: "https://github.com/klaas/Guaka.git", from: "0.3.0"),
		.package(url: "https://github.com/vapor/leaf.git", from: "3.0.0"),
		.package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
		.package(url: "https://github.com/vapor/core.git", from: "3.9.0"), /* Async */
		.package(url: "https://github.com/vapor/crypto.git", from: "3.0.0"),
		.package(url: "https://github.com/vapor/fluent-sqlite.git", from: "3.0.0"),
		.package(url: "https://github.com/behrang/YamlSwift.git", from: "3.0.0"),
		.package(url: "https://github.com/vapor/jwt.git", from: "3.0.0"),
		.package(url: "https://github.com/happn-tech/EmailValidator.git", .branch("master")),
		.package(url: "https://github.com/zoul/generic-json-swift.git", from: "1.2.0")
	],
	targets: [
		.systemLibrary(name: "COpenLDAP", providers: [.apt(["libldap2-dev"]), .brew(["openldap"])]),
		.systemLibrary(name: "COpenSSL", pkgConfig: "openssl", providers: [.apt(["openssl", "libssl-dev"]), .brew(["openssl@1.1"])]),
		
		.target(name: "Action", dependencies: []),
		
		.target(name: "OfficeKit", dependencies: [
			/* Dependencies in the project */
			"Action", "COpenLDAP", "COpenSSL",
			/* happn dependencies */
			"RetryingOperation", "URLRequestOperation", "SemiSingleton", "EmailValidator",
			/* External dependencies */
			"NIO", "FluentSQLite", "Crypto", "Vapor", "Async", "JWT", "GenericJSON"
		]),
		.testTarget(name: "OfficeKitTests", dependencies: ["OfficeKit"]),
		
		.target(name: "officectl", dependencies: ["OfficeKit", "Vapor", "Leaf", "Guaka", "Yaml", "JWT"])
	]
)
