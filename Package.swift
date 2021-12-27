// swift-tools-version:5.5
import PackageDescription



var platformDependentTargets = [PackageDescription.Target]()
var platformDependentProducts = [PackageDescription.Product]()
var platformDependentDependencies = [PackageDescription.Package.Dependency]()
var platformDependentOfficeKitDependencies = [PackageDescription.Target.Dependency]()
var platformDependentOfficectlDependencies = [PackageDescription.Target.Dependency]()

#if canImport(DirectoryService) && canImport(OpenDirectory)
platformDependentTargets.append(.executableTarget(name: "officectl_odproxy", dependencies: [
	.product(name: "Crypto",       package: "swift-crypto"),
	.product(name: "GenericJSON",  package: "GenericJSON"),
	.product(name: "JWTKit",       package: "jwt-kit"),
	.product(name: "LegibleError", package: "LegibleError"),
	.product(name: "Vapor",        package: "vapor"),
	.product(name: "Yaml",         package: "Yaml"),
	"OfficeKit"
]))
platformDependentProducts.append(.executable(name: "officectl_odproxy", targets: ["officectl_odproxy"]))
#endif

#if !canImport(Darwin)
platformDependentTargets.append(.systemLibrary(name: "CNCurses", pkgConfig: "ncurses", providers: [.apt(["libncurses-dev"]), .brew(["ncurses"])]))
platformDependentOfficectlDependencies.append("CNCurses")
#endif

#if !os(Linux)
/* On macOS we use a custom-made xcframework to avoid the deprecation warnings macOS has added on OpenLDAP
 * (they say to use OpenDirectory, but I did not find a way to do LDAP requests using OpenDirectory and I’m pretty sure it’s because it’s not possible). */
platformDependentDependencies.append(contentsOf: [
	.package(url: "https://github.com/xcode-actions/COpenSSL.git",  from: "1.1.111"),
	.package(url: "https://github.com/xcode-actions/COpenLDAP.git", from: "2.5.5")
])
platformDependentOfficeKitDependencies.append(contentsOf: [
	.product(name: "COpenSSL-dynamic",  package: "COpenSSL"),
	.product(name: "COpenLDAP-dynamic", package: "COpenLDAP")
])
#else
/* On Linux we use the standard OpenLDAP package.
 * Note: The standard OpenLDAP package does not have a pkg-config file, so no pkgconfig argument here, */
platformDependentTargets.append(.systemLibrary(name: "COpenLDAP", providers: [.apt(["libldap2-dev"]), .brew(["openldap"])]))
platformDependentOfficeKitDependencies.append(
	.target(name: "COpenLDAP")
)
#endif


let package = Package(
	name: "officectl",
	platforms: [
		.macOS(.v12)
	],
	products: [
		.library(name: "OfficeKit", targets: ["OfficeKit"]),
		.executable(name: "officectl", targets: ["officectl"])
	] + platformDependentProducts,
	dependencies: [
		.package(                     url: "https://github.com/Frizlab/APIConnectionProtocols.git", from: "1.0.0-beta.3"),
		.package(                     url: "https://github.com/Frizlab/HasResult.git", from: "1.0.0"),
		.package(                     url: "https://github.com/Frizlab/OperationAwaiting.git", from: "1.2.0-beta.1"),
		.package(                     url: "https://github.com/Frizlab/swift-email.git", from: "0.2.2"),
		.package(                     url: "https://github.com/happn-app/CollectionConcurrencyKit.git", from: "0.2.0"),
		.package(                     url: "https://github.com/happn-tech/URLRequestOperation.git", from: "2.0.0-alpha.13.1"),
		.package(                     url: "https://github.com/happn-tech/RetryingOperation.git", from: "1.1.4"),
		.package(                     url: "https://github.com/happn-tech/SemiSingleton.git", .branch("workaround_swift_crash")),
		.package(                     url: "https://github.com/apple/swift-nio.git", from: "2.6.0"),
		.package(                     url: "https://github.com/apple/swift-log.git", from: "1.2.0"),
		.package(                     url: "https://github.com/apple/swift-crypto.git", from: "1.0.0"),
		.package(                     url: "https://github.com/apple/swift-argument-parser.git", from: "0.1.0"),
		.package(                     url: "https://github.com/vapor/leaf.git", from: "4.0.0"),
		.package(                     url: "https://github.com/vapor/vapor.git", from: "4.50.0"),
//		.package(                     url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
		.package(name: "Yaml",        url: "https://github.com/behrang/YamlSwift.git", from: "3.0.0"),
		.package(                     url: "https://github.com/vapor/jwt-kit.git", from: "4.2.2"),
		.package(                     url: "https://github.com/vapor/console-kit.git", from: "4.0.0"),
		.package(name: "GenericJSON", url: "https://github.com/zoul/generic-json-swift.git", from: "1.2.0"),
		.package(                     url: "https://github.com/mxcl/LegibleError.git", from: "1.0.0"),
		.package(                     url: "https://github.com/filom/ASN1Decoder.git", from: "1.3.3"),
		.package(                     url: "https://github.com/xcode-actions/clt-logger.git", from: "0.3.4")
	] + platformDependentDependencies,
	targets: [
		.target(name: "GenericStorage", swiftSettings: [
			.unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
//			.unsafeFlags(["-Xfrontend", "-warn-concurrency", "-Xfrontend", "-enable-actor-data-race-checks"])
		]),
		
		.target(name: "ServiceKit", swiftSettings: [
			.unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
//			.unsafeFlags(["-Xfrontend", "-warn-concurrency", "-Xfrontend", "-enable-actor-data-race-checks"])
		]),
		
		.target(
			name: "OfficeKit",
			dependencies: [
				.product(name: "APIConnectionProtocols",   package: "APIConnectionProtocols"),
				.product(name: "CollectionConcurrencyKit", package: "CollectionConcurrencyKit"),
				.product(name: "Crypto",                   package: "swift-crypto"),
				.product(name: "Email",                    package: "swift-email"),
				.product(name: "GenericJSON",              package: "GenericJSON"),
				.product(name: "HasResult",                package: "HasResult"),
				.product(name: "JWTKit",                   package: "jwt-kit"),
				.product(name: "Logging",                  package: "swift-log"),
				.product(name: "NIO",                      package: "swift-nio"),
				.product(name: "OperationAwaiting",        package: "OperationAwaiting"),
				.product(name: "RetryingOperation",        package: "RetryingOperation"),
				.product(name: "SemiSingleton",            package: "SemiSingleton"),
				.product(name: "URLRequestOperation",      package: "URLRequestOperation"),
				.product(name: "Yaml",                     package: "Yaml"),
				"GenericStorage",
				"ServiceKit"
			] + platformDependentOfficeKitDependencies,
			swiftSettings: [
				.unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
//				.unsafeFlags(["-Xfrontend", "-warn-concurrency", "-Xfrontend", "-enable-actor-data-race-checks"])
			]
		),
		.testTarget(name: "OfficeKitTests", dependencies: ["OfficeKit"]),
		
		.executableTarget(
			name: "officectl",
			dependencies: [
				.product(name: "ArgumentParser",           package: "swift-argument-parser"),
				.product(name: "ASN1Decoder",              package: "ASN1Decoder"),
				.product(name: "CLTLogger",                package: "clt-logger"),
				.product(name: "CollectionConcurrencyKit", package: "CollectionConcurrencyKit"),
				.product(name: "ConsoleKit",               package: "console-kit"),
				.product(name: "Crypto",                   package: "swift-crypto"),
				.product(name: "JWTKit",                   package: "jwt-kit"),
				.product(name: "Leaf",                     package: "leaf"),
				.product(name: "LegibleError",             package: "LegibleError"),
				.product(name: "Vapor",                    package: "vapor"),
				.product(name: "Yaml",                     package: "Yaml"),
				"OfficeKit"
			] + platformDependentOfficectlDependencies,
			swiftSettings: [
				.unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
//				.unsafeFlags(["-Xfrontend", "-warn-concurrency", "-Xfrontend", "-enable-actor-data-race-checks"])
			],
			linkerSettings: [.linkedLibrary("ncurses", .when(platforms: [.macOS]))]
		)
		
	] + platformDependentTargets
)
