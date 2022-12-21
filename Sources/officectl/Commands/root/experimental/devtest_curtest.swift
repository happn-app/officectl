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

import HappnOffice
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
		let oldConfHappn: OfficeKit.HappnServiceConfig = try officeKitConfig.getServiceConfig(id: nil)
		let happnService = try HappnService(id: "hppn", jsonConfig: .object([
			"service_name": .string("happn"),
			"domain_aliases": .object(officeKitConfig.globalConfig.domainAliases.mapValues{ .string($0) }),
			"connector_settings": .object([
				"base_url": .string(oldConfHappn.connectorSettings.baseURL.absoluteString),
				"client_id": .string(oldConfHappn.connectorSettings.clientID),
				"client_secret": .string(oldConfHappn.connectorSettings.clientSecret),
				"admin_username": .string(oldConfHappn.connectorSettings.authMode.username!),
				"admin_password": .string(oldConfHappn.connectorSettings.authMode.password!),
			]),
			"user_id_builders": JSON(encodable: [
				UserIDBuilder(format: "|id|"),
				UserIDBuilder(format: "*|first_name|.|last_name|*@happn.fr")
			])
		]))
		do {
			let allServices = Set([HashableUserService(happnService), HashableUserService(googleService)])
			do {
				var françois = try await happnService.existingUser(fromID: Email(rawValue: "francois.lamboley@happn.fr")!, propertiesToFetch: nil, using: app.services)!
//				print(françois.oU_setValue("François", forProperty: .firstName, allowIDChange: false, convertMismatchingTypes: false))
				print(françois.oU_setValue("1990-06-09", forProperty: .birthdate, allowIDChange: false, convertMismatchingTypes: true))
				print(françois)
				françois = try await happnService.updateUser(françois, propertiesToUpdate: [.birthdate], using: app.services)
				print(françois)
			}
//			do {
//				var ryan = try await googleService.existingUser(fromID: Email(rawValue: "ryan.ismael@happn.fr")!, propertiesToFetch: nil, using: app.services)!
//				print(ryan.oU_setValue("Ryan", forProperty: .firstName, allowIDChange: false, convertMismatchingTypes: false))
//				ryan = try await googleService.updateUser(ryan, propertiesToUpdate: [.firstName], using: app.services)
//				print(ryan)
//			}
//			do {
//				let res = try await MultiServicesUser.fetchAll(in: allServices, using: app.services)
//				res.users.forEach{
//					print("-----")
//					print("happn: \($0[HashableUserService(happnService)]!)")
//					print("Gougle: \($0[HashableUserService(googleService)]!)")
//				}
//			}
//			do {
//				let vivien = try await googleService.existingUser(fromID: Email(rawValue: "vivien.toubeau@happn.fr")!, propertiesToFetch: nil, using: app.services)!
//				let multiVivien = try await MultiServicesUser.fetch(from: UserAndServiceFrom(user: vivien, service: googleService)!, in: allServices, propertiesToFetch: nil, using: app.services)
//				print("=====")
//				print("happn: \(multiVivien[HashableUserService(happnService)])")
//				print("Gougle: \(multiVivien[HashableUserService(googleService)])")
//			}
//			do {
//				let françois = try await googleService.existingUser(fromID: Email(rawValue: "francois.lamboley@happn.fr")!, propertiesToFetch: nil, using: app.services)!
//				let multiFrançois = try await MultiServicesUser.fetch(from: UserAndServiceFrom(user: françois, service: googleService)!, in: allServices, propertiesToFetch: nil, using: app.services)
//				print("=====")
//				print("happn: \(multiFrançois[HashableUserService(happnService)])")
//				print("Gougle: \(multiFrançois[HashableUserService(googleService)])")
//			}
//			do {
//				let allHappn = try await happnService.listAllUsers(includeSuspended: true, propertiesToFetch: nil, using: app.services)
//				let françoisfr  = allHappn.first(where: { $0.oU_id == Email(rawValue: "francois.lamboley@happn.fr")! })!
//				let françoiscom = allHappn.first(where: { $0.oU_id == Email(rawValue: "francois.lamboley@happn.com")! })!
//				let multiFrançois = try await MultiServicesUser.merge(usersAndServices: [
//					UserAndServiceFrom(user: françoisfr,  service: happnService)!,
//					UserAndServiceFrom(user: françoiscom, service: happnService)!
//				])
//				print("=====")
//				multiFrançois.forEach{
//					print("\($0[HashableUserService(happnService)]!)")
//				}
//			}
		} catch {
			print(error)
		}
//		do {
////			let user = try await googleService.existingUser(fromPersistentID: "103126761345692481320", propertiesToFetch: [.firstName, .id], using: app.services)
////			let user = try await googleService.existingUser(fromID: Email(rawValue: "formind.dev@happn.fr")!, propertiesToFetch: nil, using: app.services)
//			let users = try await googleService.listAllUsers(includeSuspended: true, propertiesToFetch: nil, using: app.services)
//			users.forEach{ print($0) }
//		} catch let error as URLRequestOperationError {
//			print(error)
//			print((error.postProcessError as? URLRequestOperationError.UnexpectedStatusCode)?.httpBody?.reduce("", { $0 + String(format: "%02x", $1) }))
//		}
//		do {
//			var newAdmin = HappnUser(login: Email(rawValue: "officectl__test_user@happn.fr")!)
//			newAdmin.firstName = "officectl"
//
//			print("Creating new test admin")
//			newAdmin = try await happnService.createUser(newAdmin, using: app.services)
//
//			print("Waiting a bit")
//			try await Task.sleep(nanoseconds: 3_000_000_000)
//
//			newAdmin.firstName = "officectl (modified)"
//			newAdmin.lastName = "Test"
//			newAdmin.gender = .female
//			do {
//				let updatedAdmin = try await happnService.updateUser(newAdmin, propertiesToUpdate: [.id, .lastName], using: app.services)
//				try await happnService.changePassword(of: updatedAdmin, to: "toto", using: app.services)
//				print(updatedAdmin)
//			} catch {
//				print(error)
//			}
//
//
//			print("Waiting again")
//			try await Task.sleep(nanoseconds: 7_000_000_000)
//
//			print("Deleting test admin")
//			try await happnService.deleteUser(newAdmin, using: app.services)
//
//			try await print(happnService.existingUser(fromID: Email(rawValue: "francois.lamboley@happn.fr")!, propertiesToFetch: nil, using: app.services))
////			try await print(happnService.existingUser(fromPersistentID: "243", propertiesToFetch: nil, using: app.services))
////			try await print(happnService.listAllUsers(propertiesToFetch: nil, using: app.services))
//		} catch let error as URLRequestOperationError {
//			print(error)
//			print((error.postProcessError as? URLRequestOperationError.UnexpectedStatusCode)?.httpBody?.reduce("", { $0 + String(format: "%02x", $1) }))
//		}
		
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
