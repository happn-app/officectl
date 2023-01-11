/*
 * devtest_curtest.swift
 * officectl
 *
 * Created by François Lamboley on 2018/06/26.
 */

import Foundation

import ArgumentParser
import Email
import GenericJSON
import Vapor

import OfficeKit
import OfficeKit2
import SemiSingleton
import URLRequestOperation

import GoogleOffice



struct CurrentDevTestCommand : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "curtest",
		abstract: "The current developer test… Should probably not be used; anything could happen!",
		shouldDisplay: false
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	func run() async throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: nil)
		try Application.runSync(officectlConfig: config, configureHandler: { _ in }, vaporRun)
	}
	
	/* We don’t technically require Vapor, but it’s convenient. */
	func vaporRun(_ context: CommandContext) async throws {
		let app = context.application
		let officeKitConfig = app.officeKitConfig
//		let officectlConfig = app.officectlConfig
//		let sProvider = app.officeKitServiceProvider
//		let semiSingletonStore = app.semiSingletonStore
//		let opQ: OperationQueue = try app.services.make()
//		let simpleMDMToken = try nil2throw(officectlConfig.tmpSimpleMDMToken)
		
		/* OfficeKit2 tests. */
		let oldConfGougle: OfficeKit.GoogleServiceConfig = try officeKitConfig.getServiceConfig(id: nil)
		let googleService = try GoogleService(id: "ggl", jsonConfig: .object([
			"service_name": .string("gougle"),
			"primary_domains": .array(oldConfGougle.primaryDomains.map{ .string($0) }),
			"connector_settings": .object([
				"admin_email": .string(oldConfGougle.connectorSettings.userBehalf!),
				"superuser_json_creds_path": .string(oldConfGougle.connectorSettings.jsonCredentialsURL.path)
			]),
			"user_id_builders": JSON(encodable: [
				UserIDBuilder(format: "*|first_name|.|last_name|*@happn.fr")
			])
		]))
		googleService.connector
		
		/* List users by creation date decreasing */
//		let gougleService: GoogleService = try app.officeKitServiceProvider.getService(id: nil)
//		let users = try await gougleService.listAllUsers(using: app.services)
//		for user in users.sorted(by: { $0.creationTime ?? .distantFuture < $1.creationTime ?? .distantFuture }) {
//			print("\(user.creationTime ?? .distantFuture) - \(user.primaryEmail)")
//		}
		
		/* Delete happn console user */
//		let consoleService: HappnService = try sProvider.getService(id: nil)
//		guard let user = try await consoleService.existingUser(fromUserID: "sebastien.gadalla@happn.fr", propertiesToFetch: [], using: app.services) else {
//			throw "Cannot get user"
//		}
//		try await consoleService.deleteUser(user, using: app.services)
		
		/* List all admins and their permissions */
//		let consoleService: HappnService = try sProvider.getService(id: nil)
//		let hConnector: HappnConnector = HappnConnector(key: consoleService.config.connectorSettings)
//		try await hConnector.connect(scope: Set(arrayLiteral: "acl_read"))
//		let userIDs = try await consoleService.listAllUsers(using: app.services).compactMap{ $0.id }
//		let operations = userIDs
//			.map{ uid -> URLRequestDataOperation<JSON> in
//				let url = consoleService.config.connectorSettings.baseURL.appendingPathComponent("api").appendingPathComponent("user-acls").appendingPathComponent(uid)
//				return URLRequestDataOperation<JSON>.forAPIRequest(url: url, requestProcessors: [AuthRequestProcessor(hConnector)], retryProviders: [])
//			}
//		for (uid, fetchedUser) in await zip(userIDs, opQ.addOperationsAndGetResults(operations)) {
//			let fetchedUser = fetchedUser.map{ $0.result }
//			switch fetchedUser {
//				case .failure(let e): print("\(uid) - Failed to fetch user: \(e)")
//				case .success(let u): print("\(uid) - \(u["data"]?["login"] ?? "no email"): \(u["data"]?["acl"]?.arrayValue?.compactMap{ $0["id"] } ?? [.string("error")])")
//			}
//		}
		
		/* Search for LDAP users without an mail */
//		let ldapConfig: LDAPServiceConfig = try app.officeKitConfig.getServiceConfig(id: nil)
//		let ldapConnector = try LDAPConnector(key: ldapConfig.connectorSettings)
//		return try await ldapConnector.connect(scope: (), eventLoop: eventLoop)
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
//			.get()
		
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
//		return try await f.get()
	}
	
}
