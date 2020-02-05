/*
 * devtest_consoleperm.swift
 * officectl
 *
 * Created by François Lamboley on 05/02/2020.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit
import SemiSingleton
import URLRequestOperation



func consolePerm(flags f: Flags, arguments args: [String], context: CommandContext, app: Application) throws -> EventLoopFuture<Void> {
	let sProvider = app.officeKitServiceProvider
	let eventLoop = try app.services.make(EventLoop.self)
	
	let hService: HappnService = try sProvider.getService(id: nil)
	let hConnector: HappnConnector = app.semiSingletonStore.semiSingleton(forKey: hService.config.connectorSettings)
	
	print(args)
	
	let group = args[1]
	let permissions: String
	switch group {
	case "acquisition": permissions = "acl_create,achievement_type_create"
	case "content":     permissions = "acl_create,achievement_type_create"
	default:            throw InvalidArgumentError(message: "Unknown group")
	}
	
	return try hService.existingUser(fromUserId: "hugo.courtecuisse@happn.fr", propertiesToFetch: [], using: app.services)
	.unwrap(or: InvalidArgumentError(message: "No user found with the given email"))
	.flatMapThrowing{ user in
		return try nil2throw(user.id.value, "no userid… (should not happen!)")
	}
	.flatMap{ userId in
		return hConnector.connect(scope: Set(arrayLiteral: "acl_update", "acl_read"), eventLoop: eventLoop).map{ _ in userId }
	}
	.flatMap{ userId -> EventLoopFuture<(result: URLRequest, userInfo: Any?)> in
		let url = hService.config.connectorSettings.baseURL.appendingPathComponent("api").appendingPathComponent("user-acls")
		
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "POST"
		urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
		
		var urlComponents = URLComponents(string: "https://example.com")!
		urlComponents.queryItems = [
			URLQueryItem(name: "user_id", value: userId),
			URLQueryItem(name: "permissions", value: permissions)
		]
		urlRequest.httpBody = Data(urlComponents.percentEncodedQuery!.utf8)
		
		return hConnector.authenticate(request: urlRequest, eventLoop: eventLoop)
	}
	.flatMap{ authenticatedURLRequest -> EventLoopFuture<Data> in
		let operation = URLRequestOperation(request: authenticatedURLRequest.result)
		return EventLoopFuture<Data>.future(from: operation, on: eventLoop, resultRetriever: { o -> Data in
			guard let data = o.fetchedData else {
				throw o.finalError ?? InternalError(message: "no data and no known error from the request")
			}
			return data
		})
	}
	.map{ data in
		app.console.print(String(data: data, encoding: .utf8) ?? data.reduce("", { $0 + String(format: "%02x", $1) }))
		return ()
	}
}
