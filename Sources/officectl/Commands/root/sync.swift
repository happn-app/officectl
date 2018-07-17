/*
 * sync.swift
 * officectl
 *
 * Created by François Lamboley on 13/07/2018.
 */

import Foundation

import Guaka
import NIO

import OfficeKit



func sync(flags f: Flags, arguments args: [String], asyncConfig: AsyncConfig) -> EventLoopFuture<Void> {
	do {
		let fromStr = f.getString(name: "from")!
		let happnUsersFuture: EventLoopFuture<[HappnUser]>
		switch fromStr.lowercased() {
		case "google": happnUsersFuture = try happnUsersFromGoogle(flags: f, asyncConfig: asyncConfig)
		case "ldap":   happnUsersFuture = try happnUsersFromLDAP(flags: f, asyncConfig: asyncConfig)
		default: throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid \"from\" value for syncing directories: \(fromStr)"])
		}
		
		let f = happnUsersFuture.then{ happnUsers -> EventLoopFuture<Void> in
			print(happnUsers)
			print(f.getString(name: "to")!.split(separator: ","))
			return asyncConfig.eventLoop.newSucceededFuture(result: ())
		}
		return f
	} catch {
		return asyncConfig.eventLoop.newFailedFuture(error: error)
	}
}

private func happnUsersFromGoogle(flags f: Flags, asyncConfig: AsyncConfig) throws -> EventLoopFuture<[HappnUser]> {
	let userBehalf = f.getString(name: "google-admin-email")!
	let scope = Set(arrayLiteral: "https://www.googleapis.com/auth/admin.directory.group", "https://www.googleapis.com/auth/admin.directory.user.readonly")
	let googleConnector = try GoogleJWTConnector(flags: f, userBehalf: userBehalf)
	let f = googleConnector.connect(scope: scope, asyncConfig: asyncConfig)
	.then{ _ -> EventLoopFuture<[GoogleUser]> in
		let searchOp = GoogleUserSearchOperation(searchedDomain: "happn.fr", googleConnector: googleConnector)
		return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.defaultOperationQueue, resultRetriever: { (searchOp) -> [GoogleUser] in try searchOp.result.successValueOrThrow() })
	}
	.map{ (googleUsers) -> [HappnUser] in
		return googleUsers.map{ user in
			HappnUser(googleUser: user)
		}
	}
	return f
}

private func happnUsersFromLDAP(flags f: Flags, asyncConfig: AsyncConfig) throws -> EventLoopFuture<[HappnUser]> {
	return asyncConfig.eventLoop.newFailedFuture(error: NSError(domain: "com.happn.officectl", code: 255, userInfo: [NSLocalizedDescriptionKey: "Not implemented"]))
}
