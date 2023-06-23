// swift-tools-version:5.7
import PackageDescription



let commonSwiftSettings: [SwiftSetting] = [
	.unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
//	.unsafeFlags(["-Xfrontend", "-warn-concurrency", "-Xfrontend", "-enable-actor-data-race-checks"])
]

let coreDependencies: [Target.Dependency] = [
	.product(name: "CollectionConcurrencyKit", package: "CollectionConcurrencyKit"),
	.product(name: "Email",                    package: "swift-email"),
	.product(name: "GenericJSON",              package: "generic-json-swift"),
	.product(name: "Logging",                  package: "swift-log"),
	.product(name: "OfficeModelCore",          package: "officectl-model"/*Xcode is not ready for this:, moduleAliases: ["OfficeModelCore": "ModelCore"]*/),
	.product(name: "UnwrapOrThrow",            package: "UnwrapOrThrow")
]

/* We do not use NIO http client. We probably should… */
let networkDependencies: [Target.Dependency] = [
	.product(name: "HasResult",           package: "HasResult"),
	.product(name: "FormURLEncodedCoder", package: "HTTPCoders"),
	.product(name: "OperationAwaiting",   package: "OperationAwaiting"),
	.product(name: "URLRequestOperation", package: "URLRequestOperation")
]

let ldapDependencies: [Target.Dependency] = {
	var ret = [Target.Dependency]()
#if !os(Linux)
	/* On macOS we use xcframework dependencies for OpenSSL and OpenLDAP. */
	ret.append(.product(name: "COpenSSL-dynamic",  package: "COpenSSL"))
	ret.append(.product(name: "COpenLDAP-dynamic", package: "COpenLDAP"))
#else
	/* On Linux we use the standard OpenLDAP package. */
	ret.append(.target(name: "COpenLDAP"))
#endif
	return ret
}()


let package = Package(
	name: "officectl",
	platforms: [
		.macOS(.v12)
	],
	products: {
		var ret = [Product]()
		/* Base framework. */
		ret.append(.library(name: "OfficeKit", targets: ["OfficeKit"]))
		/* Office implementations. */
		ret.append(.library(name: "GitHubOffice",        targets: ["GitHubOffice"]))
		ret.append(.library(name: "GoogleOffice",        targets: ["GoogleOffice"]))
		ret.append(.library(name: "HappnOffice",         targets: ["HappnOffice"]))
		ret.append(.library(name: "LDAPOffice",          targets: ["LDAPOffice"]))
		ret.append(.library(name: "OfficeKitOffice",     targets: ["OfficeKitOffice"]))
#if canImport(OpenDirectory)
		ret.append(.library(name: "OpenDirectoryOffice", targets: ["OpenDirectoryOffice"]))
#endif
		/* CLI tools. */
		ret.append(.executable(name: "officectl", targets: ["officectl"]))
#if canImport(OpenDirectory)
		ret.append(.executable(name: "officectl-odproxy", targets: ["officectl-odproxy"]))
#endif
		return ret
	}(),
	dependencies: {
		var ret = [Package.Dependency]()
		ret.append(.package(url: "https://github.com/apple/swift-asn1.git",                       from: "0.7.0"))
		ret.append(.package(url: "https://github.com/apple/swift-argument-parser.git",            from: "1.1.0"))
		ret.append(.package(url: "https://github.com/apple/swift-certificates.git",               from: "0.1.0"))
		ret.append(.package(url: "https://github.com/apple/swift-collections.git",                from: "1.0.4"))
		ret.append(.package(url: "https://github.com/apple/swift-crypto.git",                     from: "2.1.0"))
		ret.append(.package(url: "https://github.com/apple/swift-log.git",                        from: "1.4.0"))
		ret.append(.package(url: "https://github.com/apple/swift-metrics.git",                    from: "2.2.0"))
//		ret.append(.package(url: "https://github.com/apple/swift-nio.git",                        from: "2.41.0"))
		ret.append(.package(url: "https://github.com/dduan/TOMLDecoder.git",                      from: "0.2.2"))
		ret.append(.package(url: "https://github.com/Frizlab/APIConnectionProtocols.git",         from: "1.0.0-beta.6"))
		ret.append(.package(url: "https://github.com/Frizlab/HasResult.git",                      from: "2.0.0"))
		ret.append(.package(url: "https://github.com/Frizlab/OperationAwaiting.git",              from: "1.3.0-beta.1"))
		ret.append(.package(url: "https://github.com/Frizlab/stream-reader.git",                  from: "3.5.0"))
		ret.append(.package(url: "https://github.com/Frizlab/swift-email.git",                    from: "0.2.5"))
		ret.append(.package(url: "https://github.com/Frizlab/swift-xdg.git",                      from: "1.0.0-beta.1.0.1"))
		ret.append(.package(url: "https://github.com/Frizlab/UnwrapOrThrow.git",                  from: "1.0.0"))
		ret.append(.package(url: "https://github.com/happn-app/CollectionConcurrencyKit.git",     from: "0.2.0"))
		ret.append(.package(url: "https://github.com/happn-app/HTTPCoders.git",                   from: "0.1.0"))
		ret.append(.package(url: "https://github.com/happn-app/officectl-model.git",              branch: "main"))
//		ret.append(.package(url: "https://github.com/happn-app/RetryingOperation.git",            from: "1.1.7"))
		ret.append(.package(url: "https://github.com/happn-app/SemiSingleton.git",                from: "2.1.0-beta.1"))
		ret.append(.package(url: "https://github.com/happn-app/URLRequestOperation.git",          branch: "dev.final_operation"))
		ret.append(.package(url: "https://github.com/happn-app/XibLoc.git",                       from: "1.2.4"))
		ret.append(.package(url: "https://github.com/iwill/generic-json-swift.git",               from: "2.0.2"))
		ret.append(.package(url: "https://github.com/mxcl/LegibleError.git",                      from: "1.0.0"))
		ret.append(.package(url: "https://github.com/swift-server-community/SwiftPrometheus.git", from: "1.0.0"))
//		ret.append(.package(url: "https://github.com/vapor/leaf.git",                             from: "4.2.0"))
		ret.append(.package(url: "https://github.com/vapor/queues.git",                           from: "1.11.1"))
//		ret.append(.package(url: "https://github.com/vapor/queues-redis-driver.git",              from: "1.0.3"))
		ret.append(.package(url: "https://github.com/vapor/vapor.git",                            from: "4.65.0"))
//		ret.append(.package(url: "https://github.com/vapor/fluent-sqlite-driver.git",             from: "4.0.0"))
		ret.append(.package(url: "https://github.com/vapor/jwt.git",                              from: "4.2.0"))
//		ret.append(.package(url: "https://github.com/vapor/console-kit.git",                      from: "4.5.0"))
		ret.append(.package(url: "https://github.com/xcode-actions/clt-logger.git",               from: "0.5.1"))
#if !os(Linux)
		/* On macOS we use a custom-made xcframework to avoid the deprecation warnings macOS has added on OpenLDAP (they say to use OpenDirectory, but it’s a lie). */
		ret.append(.package(url: "https://github.com/xcode-actions/COpenSSL.git",                 from: "1.1.111"))
		ret.append(.package(url: "https://github.com/xcode-actions/COpenLDAP.git",                from: "2.5.5"))
#endif
#if !canImport(System)
		ret.append(.package(url: "https://github.com/apple/swift-system.git",                     from: "1.0.0"))
#endif
		return ret
	}(),
	targets: {
		var ret = [Target]()
		
		/* ***************
		   MARK: OfficeKit
		   *************** */
		ret.append(.target(
			name: "OfficeKit",
			dependencies: {
				var ret = [Target.Dependency]()
				ret.append(contentsOf: coreDependencies)
				ret.append(contentsOf: ldapDependencies)
				ret.append(.product(name: "APIConnectionProtocols", package: "APIConnectionProtocols"))
				ret.append(.product(name: "URLRequestOperation",    package: "URLRequestOperation"))
				ret.append(.product(name: "XibLoc",                 package: "XibLoc"))
				return ret
			}(),
			swiftSettings: commonSwiftSettings
		))
		ret.append(.testTarget(name: "OfficeKit-Tests", dependencies: {
			var ret = [Target.Dependency]()
			/* The tested lib. */
			ret.append(.target(name: "OfficeKit"))
			/* Dependencies for helpers and co. */
			ret.append(.product(name: "Email",       package: "swift-email"))
			ret.append(.product(name: "GenericJSON", package: "generic-json-swift"))
			return ret
		}()))
		
		/* *********************
		   MARK: Office Services
		   ********************* */
		ret.append(.target(name: "CommonOfficePropertiesFromHappn", dependencies: [.target(name: "OfficeKit")],                                                                                                                                                          path: "Sources/OfficeKitServices/ Common",     swiftSettings: commonSwiftSettings))
		ret.append(.target(name: "CommonForOfficeKitServicesTests", dependencies: [.product(name: "URLRequestOperation", package: "URLRequestOperation"), .product(name: "StreamReader", package: "stream-reader"), .product(name: "CLTLogger", package: "clt-logger")], path: "Tests/OfficeKitServices-Tests/ Common", swiftSettings: commonSwiftSettings))
		ret.append(contentsOf: targetsForService(named: "GitHubOffice",        folderName: "GitHub",    additionalDependencies: networkDependencies + [.product(name: "JWT", package: "jwt")]))
		ret.append(contentsOf: targetsForService(named: "GoogleOffice",        folderName: "Google",    additionalDependencies: networkDependencies + [.product(name: "Crypto", package: "swift-crypto"), .product(name: "JWT", package: "jwt")]))
		ret.append(contentsOf: targetsForService(named: "HappnOffice",         folderName: "happn",     additionalDependencies: networkDependencies + [.product(name: "Crypto", package: "swift-crypto")]))
		ret.append(contentsOf: targetsForService(named: "LDAPOffice",          folderName: "LDAP",      additionalDependencies: ldapDependencies))
		ret.append(contentsOf: targetsForService(named: "Office365Office",     folderName: "Office365", additionalDependencies: networkDependencies + [.product(name: "JWT", package: "jwt")]))
		ret.append(contentsOf: targetsForService(named: "OfficeKitOffice",     folderName: "OfficeKit", additionalDependencies: networkDependencies + [.product(name: "Crypto", package: "swift-crypto")]))
#if canImport(OpenDirectory)
		ret.append(contentsOf: targetsForService(named: "OpenDirectoryOffice", folderName: "OpenDirectory"))
#endif
		ret.append(contentsOf: targetsForService(named: "SynologyOffice",      folderName: "Synology",  additionalDependencies: networkDependencies))
		ret.append(contentsOf: targetsForService(named: "VaultPKIOffice",      folderName: "VaultPKI",  additionalDependencies: networkDependencies + [.product(name: "X509", package: "swift-certificates"), .product(name: "SwiftASN1", package: "swift-asn1")]))
		
		/* ************************
		   MARK: OfficeServer (lib)
		   ************************ */
		ret.append(.target(
			name: "OfficeServer",
			dependencies: {
				var ret = [Target.Dependency]()
				ret.append(.product(name: "JWT",                package: "jwt"))
				ret.append(.product(name: "Metrics",            package: "swift-metrics"))
				ret.append(.product(name: "OfficeModel",        package: "officectl-model"))
				ret.append(.product(name: "OrderedCollections", package: "swift-collections"))
				ret.append(.product(name: "Queues",             package: "queues"))
				ret.append(.product(name: "SemiSingleton",      package: "SemiSingleton"))
				ret.append(.product(name: "SwiftPrometheus",    package: "SwiftPrometheus"))
				ret.append(.product(name: "Vapor",              package: "Vapor"))
				ret.append(contentsOf: coreDependencies)
				ret.append(contentsOf: ldapDependencies) /* Not sure we need this directly but build fails in CLI if not added. */
				return ret
			}(),
			swiftSettings: commonSwiftSettings
		))
		
		/* **************************
		   MARK: officectl Executable
		   ************************** */
		ret.append(.executableTarget(
			name: "officectl",
			dependencies: {
				var ret = [Target.Dependency]()
				ret.append(.product(name: "ArgumentParser", package: "swift-argument-parser"))
				ret.append(.product(name: "CLTLogger",      package: "clt-logger"))
				ret.append(.product(name: "JWT",            package: "jwt"))
				ret.append(.product(name: "StreamReader",   package: "stream-reader"))
				ret.append(.product(name: "TOMLDecoder",    package: "TOMLDecoder"))
				ret.append(.product(name: "Vapor",          package: "Vapor"))
				ret.append(.product(name: "XDG",            package: "swift-xdg"))
#if !canImport(System)
				ret.append(.product(name: "SystemPackage",  package: "swift-system"))
#endif
				
				ret.append(.target(name: "OfficeServer"))
				
				ret.append(.target(name: "OfficeKit"))
				ret.append(.target(name: "GitHubOffice"))
				ret.append(.target(name: "GoogleOffice"))
				ret.append(.target(name: "HappnOffice"))
				ret.append(.target(name: "LDAPOffice"))
				ret.append(.target(name: "Office365Office"))
				ret.append(.target(name: "OfficeKitOffice"))
#if canImport(OpenDirectory)
				ret.append(.target(name: "OpenDirectoryOffice"))
#endif
				ret.append(.target(name: "SynologyOffice"))
				ret.append(.target(name: "VaultPKIOffice"))
				
#if !canImport(Darwin)
				ret.append(.target(name: "CNCurses"))
#endif
				return ret
			}(),
			swiftSettings: commonSwiftSettings,
			linkerSettings: [.linkedLibrary("ncurses", .when(platforms: [.macOS]))]
		))
		/* **********************************
		   MARK: officectl-odproxy Executable
		   ********************************** */
#if canImport(OpenDirectory)
		ret.append(.executableTarget(name: "officectl-odproxy", dependencies: [
			.product(name: "CLTLogger",     package: "clt-logger"),
			.product(name: "Crypto",        package: "swift-crypto"),
			.product(name: "GenericJSON",   package: "generic-json-swift"),
			.product(name: "JWT",           package: "jwt"),
			.product(name: "LegibleError",  package: "LegibleError"),
			.product(name: "TOMLDecoder",   package: "TOMLDecoder"),
			.product(name: "UnwrapOrThrow", package: "UnwrapOrThrow"),
			.product(name: "Vapor",         package: "vapor"),
			.product(name: "XDG",           package: "swift-xdg"),
			.target(name: "OfficeKit"),
			.target(name: "OfficeKitOffice"),
			.target(name: "OpenDirectoryOffice")
		]))
#endif
		
		/* ********************
		   MARK: Some C Bridges
		   ******************** */
#if !canImport(Darwin)
		ret.append(.systemLibrary(name: "CNCurses", pkgConfig: "ncurses", providers: [.apt(["libncurses-dev"]), .brew(["ncurses"])]))
#endif
#if os(Linux)
		/* On Linux we use the standard OpenLDAP package, but we need to create its module.
		 * Note: The standard OpenLDAP package does not have a pkg-config file, so no pkgconfig argument here. */
		ret.append(.systemLibrary(name: "COpenLDAP", providers: [.apt(["libldap2-dev"]), .brew(["openldap"])]))
#endif
		return ret
	}()
)


/* *******
   MARK: -
   ******* */
func targetsForService(named name: String, folderName: String, additionalDependencies: [Target.Dependency] = [], additionalSwiftSettings: [SwiftSetting] = []) -> [Target] {
	let commonServiceDependencies: [Target.Dependency] = [
		.product(name: "APIConnectionProtocols", package: "APIConnectionProtocols"),
		.target(name: "CommonOfficePropertiesFromHappn"),
		.target(name: "OfficeKit")
	]
	let mainTarget: Target = .target(
		name: name,
		dependencies: coreDependencies + commonServiceDependencies + additionalDependencies,
		path: "Sources/OfficeKitServices/" + folderName,
		swiftSettings: commonSwiftSettings + additionalSwiftSettings
	)
	let testTarget: Target = .testTarget(
		name: name + "-Tests",
		dependencies: coreDependencies + [
			.target(name: "CommonForOfficeKitServicesTests"),
			.target(name: name)
		],
		path: "Tests/OfficeKitServices-Tests/" + folderName,
		swiftSettings: commonSwiftSettings
	)
	return [testTarget, mainTarget]
}
