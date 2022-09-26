// swift-tools-version:5.7
import PackageDescription



var platformDependentTargets = [PackageDescription.Target]()
var platformDependentProducts = [PackageDescription.Product]()
var platformDependentDependencies = [PackageDescription.Package.Dependency]()
var platformDependentOfficeKitDependencies = [PackageDescription.Target.Dependency]()
var platformDependentOfficectlDependencies = [PackageDescription.Target.Dependency]()

#if canImport(DirectoryService) && canImport(OpenDirectory)
platformDependentTargets.append(.executableTarget(name: "officectl_odproxy", dependencies: [
	.product(name: "Crypto",       package: "swift-crypto"),
	.product(name: "GenericJSON",  package: "generic-json-swift"),
	.product(name: "JWT",          package: "jwt"),
	.product(name: "LegibleError", package: "LegibleError"),
	.product(name: "OfficeModel",  package: "officectl-model"),
	.product(name: "Vapor",        package: "vapor"),
	.product(name: "Yaml",         package: "YamlSwift"),
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
		.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.1.0"),
		.package(url: "https://github.com/apple/swift-crypto.git", from: "2.1.0"),
		.package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
		.package(url: "https://github.com/apple/swift-metrics.git", from: "2.2.0"),
		.package(url: "https://github.com/apple/swift-nio.git", from: "2.41.0"),
		.package(url: "https://github.com/behrang/YamlSwift.git", from: "3.4.0"),
		.package(url: "https://github.com/filom/ASN1Decoder.git", from: "1.8.0"),
		.package(url: "https://github.com/Frizlab/APIConnectionProtocols.git", from: "1.0.0-beta.4"),
		.package(url: "https://github.com/Frizlab/HasResult.git", from: "1.0.0"),
		.package(url: "https://github.com/Frizlab/OperationAwaiting.git", from: "1.2.0-beta.2"),
		.package(url: "https://github.com/Frizlab/swift-email.git", from: "0.2.3"),
		.package(url: "https://github.com/happn-app/CollectionConcurrencyKit.git", from: "0.2.0"),
		.package(url: "https://github.com/happn-app/officectl-model.git", branch: "main"),
		.package(url: "https://github.com/happn-app/RetryingOperation.git", from: "1.1.7"),
		.package(url: "https://github.com/happn-app/SemiSingleton.git", from: "2.1.0-beta.1"),
		.package(url: "https://github.com/happn-app/URLRequestOperation.git", from: "2.0.0-alpha.13.3"),
		.package(url: "https://github.com/iwill/generic-json-swift.git", from: "2.0.1"),
		.package(url: "https://github.com/mxcl/LegibleError.git", from: "1.0.0"),
		.package(url: "https://github.com/swift-server-community/SwiftPrometheus.git", from: "1.0.0"),
		.package(url: "https://github.com/vapor/leaf.git", from: "4.2.0"),
		.package(url: "https://github.com/vapor/vapor.git", from: "4.65.0"),
//		.package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
		.package(url: "https://github.com/vapor/jwt.git", from: "4.2.0"),
		.package(url: "https://github.com/vapor/console-kit.git", from: "4.5.0"),
		.package(url: "https://github.com/xcode-actions/clt-logger.git", from: "0.3.4")
	] + platformDependentDependencies,
	targets: [
		.target(name: "GenericStorage", swiftSettings: [
			.unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
//			.unsafeFlags(["-Xfrontend", "-warn-concurrency", "-Xfrontend", "-enable-actor-data-race-checks"])
		]),
		
		.target(name: "ServiceKit", swiftSettings: [
			.unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
			.unsafeFlags(["-Xfrontend", "-warn-concurrency", "-Xfrontend", "-enable-actor-data-race-checks"])
		]),
		
		.target(
			name: "OfficeKit",
			dependencies: [
				.product(name: "APIConnectionProtocols",   package: "APIConnectionProtocols"),
				.product(name: "CollectionConcurrencyKit", package: "CollectionConcurrencyKit"),
				.product(name: "Crypto",                   package: "swift-crypto"),
				.product(name: "Email",                    package: "swift-email"),
				.product(name: "GenericJSON",              package: "generic-json-swift"),
				.product(name: "HasResult",                package: "HasResult"),
				.product(name: "JWT",                      package: "jwt"),
				.product(name: "Logging",                  package: "swift-log"),
				.product(name: "NIO",                      package: "swift-nio"),
				.product(name: "OfficeModel",              package: "officectl-model"), /* We should try and get rid of this dep from there. */
				.product(name: "OperationAwaiting",        package: "OperationAwaiting"),
				.product(name: "RetryingOperation",        package: "RetryingOperation"),
				.product(name: "SemiSingleton",            package: "SemiSingleton"),
				.product(name: "URLRequestOperation",      package: "URLRequestOperation"),
				.product(name: "Yaml",                     package: "YamlSwift"),
				"GenericStorage",
				"ServiceKit"
			] + platformDependentOfficeKitDependencies,
			swiftSettings: [
				.unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
//				.unsafeFlags(["-Xfrontend", "-warn-concurrency", "-Xfrontend", "-enable-actor-data-race-checks"])
			]
		),
		.testTarget(name: "OfficeKitTests", dependencies: ["OfficeKit", .product(name: "OfficeModel", package: "officectl-model")]),
		
		.executableTarget(
			name: "officectl",
			dependencies: [
				.product(name: "ArgumentParser",           package: "swift-argument-parser"),
				.product(name: "ASN1Decoder",              package: "ASN1Decoder"),
				.product(name: "CLTLogger",                package: "clt-logger"),
				.product(name: "CollectionConcurrencyKit", package: "CollectionConcurrencyKit"),
				.product(name: "ConsoleKit",               package: "console-kit"),
				.product(name: "Crypto",                   package: "swift-crypto"),
				.product(name: "JWT",                      package: "jwt"),
				.product(name: "Leaf",                     package: "leaf"),
				.product(name: "LegibleError",             package: "LegibleError"),
				.product(name: "Metrics",                  package: "swift-metrics"),
				.product(name: "OfficeModel",              package: "officectl-model"),
				.product(name: "SwiftPrometheus",          package: "SwiftPrometheus"),
				.product(name: "Vapor",                    package: "vapor"),
				.product(name: "Yaml",                     package: "YamlSwift"),
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
