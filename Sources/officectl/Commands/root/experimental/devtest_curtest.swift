/*
 * devtest_curtest.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import ArgumentParser
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
		let sProvider = app.officeKitServiceProvider
		
		let consoleService: HappnService = try sProvider.getService(id: nil)
		return try consoleService.existingUser(fromUserId: "anna.bansard@happn.fr", propertiesToFetch: [], using: app.services)
			.flatMapThrowing{
				guard let user = $0 else {throw "Cannot get user"}
				return user
			}
			.flatMapThrowing{ user in
				try consoleService.deleteUser(user, using: app.services)
			}
			.flatMap{ $0 }
		
		/* List all GitHub project’s hooks */
//		let c = try GitHubJWTConnector(key: officeKitConfig.gitHubConfigOrThrow().connectorSettings)
//		let f = c.connect(scope: (), eventLoop: context.container.eventLoop)
//		.then{ _ -> EventLoopFuture<[GitHubRepository]> in
//			let op = GitHubRepositorySearchOperation(searchedOrganisation: "happn-app", gitHubConnector: c)
//			return EventLoopFuture<[GitHubRepository]>.future(from: op, eventLoop: context.container.eventLoop, resultRetriever: { try $0.result.get() })
//		}
//		.then{ repositories -> EventLoopFuture<[FutureResult<[Hook]>]> in
//			let ops = repositories.map{ rep -> AuthenticatedJSONOperation<[Hook]> in
//				var config = URLRequestOperation.Config(request: URLRequest(url: URL(string: "https://api.github.com/repos/" + rep.fullName + "/hooks")!), session: nil)
//				config.acceptableStatusCodes = nil
//				return AuthenticatedJSONOperation<[Hook]>(config: config, authenticator: { request, handler in
//					var request = request
//					request.addValue("Basic THIS_AWESOME_TOKEN", forHTTPHeaderField: "Authorization")
//					handler(.success(request), nil)
//				})
//			}
//			return EventLoopFuture<[FutureResult<[Hook]>]>.executeAll(ops, eventLoop: context.container.eventLoop)
//		}
//		.map{ hooks in
//			let hooks = Set(hooks.flatMap{ $0.result ?? [] }.filter{ $0.config.url.absoluteString.contains("email") })
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
