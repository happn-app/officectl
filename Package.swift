// swift-tools-version:5.2
import PackageDescription



var platformDependentTargets = [PackageDescription.Target]()
var platformDependentProducts = [PackageDescription.Product]()
var platformDependentOfficeKitDependencies = [Target.Dependency]()
var platformDependentOfficectlDependencies = [Target.Dependency]()

#if canImport(DirectoryService) && canImport(OpenDirectory)
platformDependentTargets.append(.target(name: "officectl_odproxy", dependencies: [
	"OfficeKit",
	.product(name: "Crypto", package: "swift-crypto"),
	.product(name: "Vapor", package: "vapor"),
	"Yaml",
	.product(name: "JWTKit", package: "jwt-kit"),
	"LegibleError", "GenericJSON"
]))
platformDependentProducts.append(.executable(name: "officectl_odproxy", targets: ["officectl_odproxy"]))
#endif

#if !canImport(Darwin)
platformDependentTargets.append(.systemLibrary(name: "CNCurses", pkgConfig: "ncurses", providers: [.apt(["libncurses-dev"]), .brew(["ncurses"])]))
platformDependentOfficectlDependencies.append("CNCurses")
#endif

#if !canImport(Security)
/* See the Crypto.swift for this */
platformDependentOfficeKitDependencies.append(
	.product(name: "JWTKit", package: "jwt-kit")
)
#endif


/* We try and use OpenLDAP from Homebrew instead of the system one if possible
 * (the system one is deprecated, but there are no alternatives; OpenDirectory
 * simply does not do what OpenLDAP does).
 * Note the project compiles if the system OpenLDAP is used, but you’ll get a
 * lot of useless warnings.
 *
 * To have the project opened with Xcode from the Package.swift file (and not
 * use an xcodeproj file), launch Xcode from the Terminal w/:
 *    PKG_CONFIG_PATH="$PKG_CONFIG_PATH:`brew --prefix openssl@1.1`/lib/pkgconfig" xed .
 * … or simply `xed .` if your `PKG_CONFIG_PATH` is already correctly set.
 *
 * This is required, because contrary to the CLI’s SPM which is aware of brew,
 * it seems Xcode’s isn’t. */
let openLDAPTarget: Target
#if os(macOS) /* Probably iOS, watchOS and tvOS too, but I’m not sure and we do not really care for now… */
/* On macOS we use a custom-made auto-generated pkg-config file for OpenLDAP
 * because the upstream did not do a pkg-config file.
 * (On macOS, the brew OpenLDAP install is keg-only, which means the headers and
 *  lib folders cannot be guessed, and a pkg-config has to be provided.)
 * I tried auto-generating the pkgconfig folder with the .pc files for OpenLDAP
 * directly from the Package.swift file (yes, ugly), but it does not work.
 * So instead we’ll recommend people to use the `configure.sh` script.
 *
 * Note: We cannot provide LDFLAGS and CFLAGS because AFAICT SPM completely
 * ignores those variables. Only the PKG_CONFIG_PATH var seems to be read.
 * Also, the linker and cflags parameters available on a standard target are not
 * available on a system library target. */
openLDAPTarget = .systemLibrary(name: "COpenLDAP", pkgConfig: "openldap", providers: [.apt(["libldap2-dev"]), .brew(["openldap"])])
#else
/* On Linux we use the standard OpenLDAP package. The standard OpenLDAP package
 * does not have a pkg-config file! */
openLDAPTarget = .systemLibrary(name: "COpenLDAP", providers: [.apt(["libldap2-dev"]), .brew(["openldap"])])
#endif


let package = Package(
	name: "officectl",
	platforms: [
		.macOS(.v10_15)
	],
	products: [
		.library(name: "OfficeKit", targets: ["OfficeKit"]),
		.executable(name: "officectl", targets: ["officectl"])
	] + platformDependentProducts,
	dependencies: [
		.package(                     url: "https://github.com/happn-tech/URLRequestOperation.git", from: "1.1.7"),
		.package(                     url: "https://github.com/happn-tech/RetryingOperation.git", from: "1.1.4"),
		.package(                     url: "https://github.com/happn-tech/SemiSingleton.git", from: "2.0.0"),
		.package(                     url: "https://github.com/apple/swift-nio.git", from: "2.6.0"),
		.package(                     url: "https://github.com/apple/swift-log.git", from: "1.2.0"),
		.package(                     url: "https://github.com/apple/swift-crypto.git", from: "1.0.0"),
		.package(                     url: "https://github.com/apple/swift-argument-parser.git", from: "0.1.0"),
		.package(                     url: "https://github.com/vapor/leaf.git", from: "4.0.0-rc"),
		.package(                     url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
//		.package(                     url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
		.package(name: "Yaml",        url: "https://github.com/behrang/YamlSwift.git", from: "3.0.0"),
		.package(                     url: "https://github.com/vapor/jwt-kit.git", from: "4.0.0-rc"),
		.package(                     url: "https://github.com/vapor/console-kit.git", from: "4.0.0"),
		.package(                     url: "https://github.com/happn-tech/EmailValidator.git", .branch("master")),
		.package(name: "GenericJSON", url: "https://github.com/zoul/generic-json-swift.git", from: "1.2.0"),
		.package(                     url: "https://github.com/mxcl/LegibleError.git", from: "1.0.0")
	],
	targets: [
		openLDAPTarget,
		.systemLibrary(name: "COpenSSL", pkgConfig: "openssl", providers: [.apt(["openssl", "libssl-dev"]), .brew(["openssl@1.1"])]),
		
		.target(name: "GenericStorage", dependencies: []),
		
		.target(name: "ServiceKit", dependencies: []),
		
		.target(
			name: "OfficeKit",
			dependencies: [
				/* Dependencies in the project */
				"COpenLDAP", "GenericStorage", "ServiceKit",
				/* happn dependencies */
				"RetryingOperation", "URLRequestOperation", "SemiSingleton", "EmailValidator",
				/* External dependencies */
				.product(name: "NIO", package: "swift-nio"),
				.product(name: "Logging", package: "swift-log"),
				.product(name: "Crypto", package: "swift-crypto"),
				"GenericJSON", "Yaml"
			] + platformDependentOfficeKitDependencies
		),
		.testTarget(name: "OfficeKitTests", dependencies: ["OfficeKit"]),
		
		.target(
			name: "officectl",
			dependencies:
				["OfficeKit",
				 .product(name: "Crypto", package: "swift-crypto"),
				 "COpenSSL",
				 .product(name: "Vapor", package: "vapor"),
				 .product(name: "Leaf", package: "leaf"),
				 .product(name: "ConsoleKit", package: "console-kit"),
				 .product(name: "ArgumentParser", package: "swift-argument-parser"),
				 "Yaml",
				 .product(name: "JWTKit", package: "jwt-kit"),
				 "LegibleError"
			] + platformDependentOfficectlDependencies,
			linkerSettings: [.linkedLibrary("ncurses", .when(platforms: [.macOS]))]
		)
		
	] + platformDependentTargets
)
