/*
 * GoogleUserSearchOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 17/07/2018.
 */

import Foundation

import AsyncOperationResult
import RetryingOperation



public class GoogleUserSearchOperation : RetryingOperation {
	
	public static let searchScopes = Set(arrayLiteral: "https://www.googleapis.com/auth/admin.directory.group", "https://www.googleapis.com/auth/admin.directory.user.readonly")
	
	public let searchedDomain: String
	public let connector: GoogleJWTConnector
	
	public var result = AsyncOperationResult<[GoogleUser]>.error(OperationIsNotFinishedError())
	
	public init(searchedDomain d: String, googleConnector: GoogleJWTConnector) {
		assert(googleConnector.isConnected)
		connector = googleConnector
		searchedDomain = d
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		fetchNextPage(nextPageToken: nil)
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
	/* ***************
      MARK: - Private
	   *************** */
	
	private var users = [GoogleUser]()
	
	private func fetchNextPage(nextPageToken: String?) {
		var urlComponents = URLComponents(string: "https://www.googleapis.com/admin/directory/v1/users")!
		urlComponents.queryItems = [URLQueryItem(name: "domain", value: searchedDomain)]
		if let t = nextPageToken {urlComponents.queryItems!.append(URLQueryItem(name: "pageToken", value: t))}
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .customISO8601
		decoder.keyDecodingStrategy = .useDefaultKeys
		let op = AuthenticatedJSONOperation<GoogleUsersList>(url: urlComponents.url!, authenticator: connector.authenticate, decoder: decoder)
		op.completionBlock = {
			guard let o = op.decodedObject else {
				self.result = .error(op.finalError ?? NSError(domain: "com.happn.officectl", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown error while fetching the users"]))
				self.baseOperationEnded()
				return
			}
			
			self.users.append(contentsOf: o.users)
			if let t = o.nextPageToken {self.fetchNextPage(nextPageToken: t)}
			else                       {self.result = .success(self.users); self.baseOperationEnded()}
		}
		op.start()
	}
	
}
