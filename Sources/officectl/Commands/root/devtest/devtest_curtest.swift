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
import URLRequestOperation



func curTest(flags f: Flags, arguments args: [String], context: CommandContext) throws -> EventLoopFuture<Void> {
	let asyncConfig: AsyncConfig = try context.container.make()
	let officeKitConfig = try context.container.make(OfficeKitConfig.self)
	
//	let c = try GitHubJWTConnector(key: officeKitConfig.gitHubConfigOrThrow().connectorSettings)
//	let f = c.connect(scope: (), asyncConfig: asyncConfig)
//	.then{ _ -> Future<[GitHubRepository]> in
//		let op = GitHubRepositorySearchOperation(searchedOrganisation: "happn-app", gitHubConnector: c)
//		return asyncConfig.eventLoop.future(from: op, queue: asyncConfig.operationQueue, resultRetriever: { try $0.result.successValueOrThrow() })
//	}
//	.then{ repositories -> EventLoopFuture<Void> in
//		for r in repositories {
//			print("https://github.com/" + r.fullName + "/settings/installations")
//		}
//		return asyncConfig.eventLoop.newSucceededFuture(result: ())
//	}
//	return f
	
	let googleConnectorConfig = try officeKitConfig.googleConfigOrThrow().connectorSettings
	_ = try nil2throw(googleConnectorConfig.userBehalf, "Google User Behalf")
	
	let c = try GoogleJWTConnector(key: googleConnectorConfig)
	let f = c.connect(scope: ModifyGoogleUserOperation.scopes, asyncConfig: asyncConfig)
	.then{ _ -> EventLoopFuture<GoogleUser> in
		let searchOp = GetGoogleUserOperation(userKey: "deletion.test@happn.fr", connector: c)
		return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.operationQueue, resultRetriever: { try $0.result.successValueOrThrow() })
	}
	.then{ user -> EventLoopFuture<Void> in
		var user = user
		user.name.familyName = "SuperTest"
		let modifyUserOp = ModifyGoogleUserOperation(user: user, propertiesToUpdate: ["name"], connector: c)
		return asyncConfig.eventLoop.future(from: modifyUserOp, queue: asyncConfig.operationQueue, resultRetriever: { _ in return })
	}
	return f
}
