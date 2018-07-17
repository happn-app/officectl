/*
 * list-users.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import Guaka

import OfficeKit



class ListUsersOperation : CommandOperation {
	
	var users = [GoogleUser]()
	
	override init(command c: Command, flags f: Flags, arguments args: [String]) {
		do {
			let userBehalf = f.getString(name: "google-admin-email")!
			let scope = Set(arrayLiteral: "https://www.googleapis.com/auth/admin.directory.group", "https://www.googleapis.com/auth/admin.directory.user.readonly")
			googleConnectorOperation = try GetConnectedGoogleConnector(flags: f, scope: scope, userBehalf: userBehalf)
		} catch {
			c.fail(statusCode: (error as NSError).code, errorMessage: error.localizedDescription)
		}
		
		super.init(command: c, flags: f, arguments: args)
		
		addDependency(googleConnectorOperation)
	}
	
	override var isAsynchronous: Bool {
		return true
	}
	
	override func startBaseOperation(isRetry: Bool) {
		if let e = googleConnectorOperation.connectionError as NSError? {
			command.fail(statusCode: e.code, errorMessage: e.localizedDescription)
		}
		
		fetchNextPage(nextPageToken: nil)
	}
	
	private let googleConnectorOperation: GetConnectedGoogleConnector
	private var googleConnector: GoogleJWTConnector {return googleConnectorOperation.connector}
	
	private func fetchNextPage(nextPageToken: String?) {
		var urlComponents = URLComponents(string: "https://www.googleapis.com/admin/directory/v1/users")!
		urlComponents.queryItems = [URLQueryItem(name: "domain", value: "happn.fr")]
		if let t = nextPageToken {urlComponents.queryItems!.append(URLQueryItem(name: "pageToken", value: t))}
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .customISO8601
		decoder.keyDecodingStrategy = .useDefaultKeys
		let op = AuthenticatedJSONOperation<GoogleUsersList>(url: urlComponents.url!, authenticator: googleConnector.authenticate, decoder: decoder)
		op.completionBlock = {
			guard let o = op.decodedObject else {
				self.command.fail(statusCode: 1, errorMessage: op.finalError?.localizedDescription ?? "Unknown error while fetching the users")
			}
			self.users.append(contentsOf: o.users)
			if let t = o.nextPageToken {self.fetchNextPage(nextPageToken: t)}
			else {
				var i = 1
				for user in self.users {
					print(user.primaryEmail.stringValue + ",", terminator: "")
					if i == 69 {print(); print(); i = 0}
					i += 1
				}
				print()
				self.baseOperationEnded()
			}
		}
		op.start()
	}
	
}
