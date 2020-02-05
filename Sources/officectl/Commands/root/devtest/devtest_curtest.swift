/*
 * devtest_curtest.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit
import SemiSingleton
import URLRequestOperation



func curTest(flags f: Flags, arguments args: [String], context: CommandContext) throws -> Future<Void> {
//	return context.container.future()
	
	let sProvider = try context.container.make(OfficeKitServiceProvider.self)
	let hService: HappnService = try sProvider.getDirectoryService(id: nil)
	let eService: EmailService = try sProvider.getDirectoryService(id: nil)
	
	let u = try! hService.logicalUser(fromEmail: Email(string: "ldap.test.1@happn.fr")!, hints: [.firstName: "LDAP", .lastName: "Not a Test (But a Test Quand Même)", .password: "toto"], emailService: eService)
	return try hService.createUser(u, on: context.container).map{ _ in }
//	return try hService.existingUser(fromUserId: "ldap.test.1@happn.fr", propertiesToFetch: [], on: context.container)
//	.flatMap{ u in try hService.deleteUser(u!, on: context.container) }
	
	/* List all GitHub project’s hooks */
//	let c = try GitHubJWTConnector(key: officeKitConfig.gitHubConfigOrThrow().connectorSettings)
//	let f = c.connect(scope: (), eventLoop: context.container.eventLoop)
//	.then{ _ -> Future<[GitHubRepository]> in
//		let op = GitHubRepositorySearchOperation(searchedOrganisation: "happn-app", gitHubConnector: c)
//		return Future<[GitHubRepository]>.future(from: op, eventLoop: context.container.eventLoop, resultRetriever: { try $0.result.get() })
//	}
//	.then{ repositories -> Future<[FutureResult<[Hook]>]> in
//		let ops = repositories.map{ rep -> AuthenticatedJSONOperation<[Hook]> in
//			var config = URLRequestOperation.Config(request: URLRequest(url: URL(string: "https://api.github.com/repos/" + rep.fullName + "/hooks")!), session: nil)
//			config.acceptableStatusCodes = nil
//			return AuthenticatedJSONOperation<[Hook]>(config: config, authenticator: { request, handler in
//				var request = request
//				request.addValue("Basic THIS_AWESOME_TOKEN", forHTTPHeaderField: "Authorization")
//				handler(.success(request), nil)
//			})
//		}
//		return Future<[FutureResult<[Hook]>]>.executeAll(ops, eventLoop: context.container.eventLoop)
//	}
//	.map{ hooks in
//		let hooks = Set(hooks.flatMap{ $0.result ?? [] }.filter{ $0.config.url.absoluteString.contains("email") })
//		let hooksStr = Data(hooks.reduce("", { $0 + $1.url.absoluteString + "\n" }).utf8)
//		_ = try? hooksStr.write(to: URL(fileURLWithPath: "/Users/frizlab/Desktop/toto.txt"))
//	}
//
//	struct Hook : Codable, Hashable {
//
//		var id: Int
//		var url: URL
//		var name: String
//
//		var config: Config
//
//		struct Config : Codable, Hashable {
//			var url: URL
//			var contentType: String
//		}
//
//	}
//
//	return f
}
