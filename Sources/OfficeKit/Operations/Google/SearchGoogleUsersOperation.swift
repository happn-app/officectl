/*
 * SearchGoogleUsersOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 17/07/2018.
 */

import Foundation

import AsyncOperationResult
import RetryingOperation



/* https://developers.google.com/admin-sdk/directory/v1/reference/users/list */
public class SearchGoogleUsersOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = [GoogleUser]
	
	public static let scopes = Set(arrayLiteral: "https://www.googleapis.com/auth/admin.directory.group", "https://www.googleapis.com/auth/admin.directory.user.readonly")
	
	public let connector: GoogleJWTConnector
	public let request: GoogleUserSearchRequest
	
	public private(set) var result = AsyncOperationResult<[GoogleUser]>.error(OperationIsNotFinishedError())
	public func resultOrThrow() throws -> [GoogleUser] {
		return try result.successValueOrThrow()
	}
	
	public init(searchedDomain d: String, query: String? = nil, googleConnector: GoogleJWTConnector) {
		connector = googleConnector
		request = GoogleUserSearchRequest(domain: d, query: query)
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		assert(connector.isConnected)
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
		urlComponents.queryItems = [URLQueryItem(name: "domain", value: request.domain)]
		if let q = request.query {urlComponents.queryItems!.append(URLQueryItem(name: "query", value: q))}
		if let t = nextPageToken {urlComponents.queryItems!.append(URLQueryItem(name: "pageToken", value: t))}
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .customISO8601
		decoder.keyDecodingStrategy = .useDefaultKeys
		let op = AuthenticatedJSONOperation<GoogleUsersList>(url: urlComponents.url!, authenticator: connector.authenticate, decoder: decoder)
		op.completionBlock = {
			guard let o = op.result else {
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


public struct GoogleUserSearchRequest {
	
	let domain: String
	/** The query for the search. If `nil`, the search will return all users in
	the given domain. No validation on the query is done. The format is described
	here: https://developers.google.com/admin-sdk/directory/v1/guides/search-users */
	let query: String?
	
	public init(domain d: String, query q: String?) {
		query = q
		domain = d
	}
	
}
