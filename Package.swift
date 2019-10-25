// swift-tools-version:5.1
import PackageDescription



var platformDependentTargets = [PackageDescription.Target]()
#if canImport(DirectoryService) && canImport(OpenDirectory)
platformDependentTargets.append(.target(name: "officectl_odproxy", dependencies: ["OfficeKit", "Vapor", "Yaml", "JWTKit", "LegibleError", "GenericJSON"]))
#endif


let package = Package(
	name: "officectl",
	platforms: [
		.macOS(.v10_13)
	],
	products: [
		.library(name: "OfficeKit", targets: ["OfficeKit"])
	],
	dependencies: [
		.package(url: "https://github.com/happn-tech/URLRequestOperation.git", from: "1.1.7"),
		.package(url: "https://github.com/happn-tech/RetryingOperation.git", from: "1.1.4"),
		.package(url: "https://github.com/happn-tech/SemiSingleton.git", from: "2.0.0"),
		.package(url: "https://github.com/apple/swift-nio.git", from: "2.6.0"),
		.package(url: "https://github.com/klaas/Guaka.git", .upToNextMinor(from: "0.3.0")),
//		.package(url: "https://github.com/vapor/leaf.git", from: "3.0.0"),
		.package(url: "https://github.com/vapor/vapor.git", .revision("4.0.0-alpha.3.2")),
//		.package(url: "https://github.com/vapor/core.git", from: "3.9.0"), /* Async */
		.package(url: "https://github.com/vapor/open-crypto.git", from: "4.0.0-alpha"),
//		.package(url: "https://github.com/vapor/fluent-sqlite.git", from: "3.0.0"),
//		.package(url: "https://github.com/vapor/service.git", from: "1.0.0"),
		.package(url: "https://github.com/vapor/console-kit.git", .revision("4.0.0-alpha.3")), /* Logging */
		.package(url: "https://github.com/behrang/YamlSwift.git", from: "3.0.0"),
		.package(url: "https://github.com/vapor/jwt.git", from: "4.0.0-alpha"),
		.package(url: "https://github.com/happn-tech/EmailValidator.git", .branch("master")),
		.package(url: "https://github.com/zoul/generic-json-swift.git", from: "1.2.0"),
		.package(url: "https://github.com/mxcl/LegibleError.git", from: "1.0.0")
	],
	targets: [
		.systemLibrary(name: "COpenLDAP", providers: [.apt(["libldap2-dev"]), .brew(["openldap"])]),
		.systemLibrary(name: "COpenSSL", pkgConfig: "openssl", providers: [.apt(["openssl", "libssl-dev"]), .brew(["openssl@1.1"])]),
		
		.target(name: "GenericStorage", dependencies: []),
		
		.target(name: "OfficeKit", dependencies: [
			/* Dependencies in the project */
			"COpenLDAP", "COpenSSL", "GenericStorage",
			/* happn dependencies */
			"RetryingOperation", "URLRequestOperation", "SemiSingleton", "EmailValidator",
			/* External dependencies */
			"NIO", "OpenCrypto"/*, "Service"*/, "ConsoleKit"/*, "Async"*/, "JWTKit", "GenericJSON", "Yaml"
			/* IMHO this one shouldn’t be needed, but I can’t seem to get rid of it
			 * in Xcode. Works well with SPM CLI. */
			,"Vapor"
		]),
		.testTarget(name: "OfficeKitTests", dependencies: ["OfficeKit"]),
		
		.target(name: "officectl", dependencies: ["OfficeKit", "Vapor"/*, "Leaf"*/, "OpenCrypto", "Guaka", "Yaml", "JWTKit", "LegibleError"])
		
	] + platformDependentTargets
)
