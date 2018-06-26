/*
 * list-users.swift
 * ghapp
 *
 * Created by François Lamboley on 6/26/18.
 */

import Guaka
import Foundation



class ListUsersOperation : CommandOperation {
	
	var users = [GoogleUser]()
	
	override init(command c: Command, flags f: Flags, arguments args: [String]) {
		let scope = GoogleJWTConnectorScope(userBehalf: f.getString(name: "admin-email")!, scope: ["https://www.googleapis.com/auth/admin.directory.group", "https://www.googleapis.com/auth/admin.directory.user.readonly"])
		googleConnectorOperation = GetConnectedGoogleConnector(command: c, flags: f, arguments: args, scope: scope)
		
		super.init(command: c, flags: f, arguments: args)
		
		addDependency(googleConnectorOperation)
	}
	
	override func startBaseOperation(isRetry: Bool) {
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
		let op = AuthenticatedJSONOperation<GoogleUsersList>(url: urlComponents.url!, authConfig: .init(authenticator: googleConnector.authenticate, decoder: decoder))
		op.completionBlock = {
			guard let o = op.decodedObject else {
				self.command.fail(statusCode: 1, errorMessage: op.finalError?.localizedDescription ?? "Unknown error while fetching the users")
			}
			self.users.append(contentsOf: o.users)
			if let t = o.nextPageToken {self.fetchNextPage(nextPageToken: t)}
			else {
				var i = 1
				for user in self.users {
					print(user.primaryEmail + ",", terminator: "")
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
