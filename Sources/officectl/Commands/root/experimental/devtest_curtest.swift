/*
 * devtest_curtest.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import ArgumentParser
import GenericJSON
import Vapor

import OfficeKit
import SemiSingleton
import URLRequestOperation



struct CurrentDevTestCommand : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "curtest",
		abstract: "The current developer test… Should probably not be used; anything could happen!",
		shouldDisplay: false
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	func run() throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: { _ in }, vaporRun)
	}
	
	/* We don’t technically require Vapor, but it’s convenient. */
	func vaporRun(_ context: CommandContext) throws -> EventLoopFuture<Void> {
		let app = context.application
		let officeKitConfig = app.officeKitConfig
		let officectlConfig = app.officectlConfig
		let sProvider = app.officeKitServiceProvider
		let semiSingletonStore = app.semiSingletonStore
		let eventLoop: EventLoop = try app.services.make()
		let simpleMDMToken = try nil2throw(officectlConfig.tmpSimpleMDMToken)
		
		/* List users by creation date decreasing */
		let gougleService: GoogleService = try app.officeKitServiceProvider.getService(id: nil)
		return try gougleService.listAllUsers(using: app.services)
			.map{ users in
				for user in users.sorted(by: { $0.creationTime.value ?? .distantFuture < $1.creationTime.value ?? .distantFuture }) {
					print("\(user.creationTime.value ?? .distantFuture) - \(user.primaryEmail)")
				}
				return ()
			}
		
		/* Delete happn console user */
//		let consoleService: HappnService = try sProvider.getService(id: nil)
//		return try consoleService.existingUser(fromUserId: "happn.agent16@tana.admvalue.com", propertiesToFetch: [], using: app.services)
//			.flatMapThrowing{
//				guard let user = $0 else {throw "Cannot get user"}
//				return user
//			}
//			.flatMapThrowing{ user in
//				try consoleService.deleteUser(user, using: app.services)
//			}
//			.flatMap{ $0 }
		
		/* List all admins and their permissions */
//		let consoleService: HappnService = try sProvider.getService(id: nil)
//		let hConnector: HappnConnector = app.semiSingletonStore.semiSingleton(forKey: consoleService.config.connectorSettings)
//		return hConnector.connect(scope: Set(arrayLiteral: "acl_update", "acl_read"), eventLoop: eventLoop)
//			.flatMapThrowing{ _ in
//				try consoleService.listAllUsers(using: app.services)
//			}
//			.flatMap{ $0 }
//			.flatMap{ users in
//				let uidAndFutures = users
//					.compactMap{ $0.id.value }
//					.map{ uid -> (String, EventLoopFuture<JSON>) in
//						let url = consoleService.config.connectorSettings.baseURL.appendingPathComponent("api").appendingPathComponent("user-acls").appendingPathComponent(uid)
//						let op = AuthenticatedJSONOperation<JSON>(url: url, authenticator: hConnector.authenticate)
//						return (uid, EventLoopFuture<JSON>.future(from: op, on: eventLoop))
//					}
//				return EventLoopFuture.waitAll(uidAndFutures, eventLoop: eventLoop)
//			}
//			.map{ (requestsAndUserInfo: [(String, Result<JSON, Error>)]) in
//				for (uid, res) in requestsAndUserInfo {
//					print("\(uid) - \(res.successValue?["data"]?["login"] ?? "no email"): \(res.successValue?["data"]?["acl"]?.arrayValue?.compactMap{ $0["id"] } ?? [.string("error")])")
//				}
//				return ()
//			}
		
		/* Search for LDAP users without an mail */
//		let ldapConfig: LDAPServiceConfig = try app.officeKitConfig.getServiceConfig(id: nil)
//		let ldapConnector = try LDAPConnector(key: ldapConfig.connectorSettings)
//		return ldapConnector.connect(scope: (), eventLoop: eventLoop)
//			.flatMap{
//				let query = LDAPSearchQuery.not(.present(attribute: LDAPAttributeDescription.mail))
//				let request = LDAPSearchRequest(scope: .children, base: ldapConfig.baseDNs.peopleBaseDNPerDomain!.values.randomElement()!, searchQuery: query, attributesToFetch: nil)
//				let searchOperation = SearchLDAPOperation(ldapConnector: ldapConnector, request: request)
//				return EventLoopFuture<(results: [LDAPObject], references: [[String]])>.future(from: searchOperation, on: eventLoop)
//			}
//			.map{ (searchResults: (results: [LDAPObject], references: [[String]])) in
//				for r in searchResults.results {
//					print(r)
//				}
//				return ()
//			}
		
		/* List all GitHub project’s hooks */
//		let gitHubConfig: GitHubServiceConfig = try officeKitConfig.getServiceConfig(id: nil)
//		let c = try GitHubJWTConnector(key: gitHubConfig.connectorSettings)
//		let f = c.connect(scope: (), eventLoop: eventLoop)
//		.flatMap{ _ -> EventLoopFuture<[GitHubRepository]> in
//			let op = GitHubRepositorySearchOperation(searchedOrganisation: "happn-app", gitHubConnector: c)
//			return EventLoopFuture<[GitHubRepository]>.future(from: op, on: eventLoop)
//		}
//		.flatMap{ repositories -> EventLoopFuture<[Result<[Hook], Error>]> in
//			let ops = repositories.map{ rep -> AuthenticatedJSONOperation<[Hook]> in
//				var config = URLRequestOperation.Config(request: URLRequest(url: URL(string: "https://api.github.com/repos/" + rep.fullName + "/hooks")!), session: nil)
//				config.acceptableStatusCodes = nil
//				return AuthenticatedJSONOperation<[Hook]>(config: config, authenticator: { request, handler in
//					var request = request
//					request.addValue("Basic THIS_AWESOME_TOKEN", forHTTPHeaderField: "Authorization")
//					handler(.success(request), nil)
//				})
//			}
//			return EventLoopFuture<[Result<[Hook], Error>]>.executeAll(ops, on: eventLoop)
//		}
//		.map{ hooks in
//			let hooks = Set(hooks.flatMap{ $0.successValue ?? [] }.filter{ $0.config.url.absoluteString.contains("email") })
//			let hooksStr = Data(hooks.reduce("", { $0 + $1.url.absoluteString + "\n" }).utf8)
//			_ = try? hooksStr.write(to: URL(fileURLWithPath: "/Users/frizlab/Desktop/toto.txt"))
//		}
//
//		struct Hook : Codable, Hashable {
//
//			var id: Int
//			var url: URL
//			var name: String
//
//			var config: Config
//
//			struct Config : Codable, Hashable {
//				var url: URL
//				var contentType: String
//			}
//
//		}
//
//		return f
	}
	
}
