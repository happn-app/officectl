/*
 * SearchHappnUsersOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 29/08/2019.
 */

import Foundation

import RetryingOperation



public final class SearchHappnUsersOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = [HappnUser]
	
	public static let scopes = Set(arrayLiteral: "admin_read", "admin_search_user")
	
	public let connector: HappnConnector
	public let request: String?
	
	public private(set) var result = Result<[HappnUser], Error>.failure(OperationIsNotFinishedError())
	
	public init(query: String? = nil, happnConnector: HappnConnector) {
		connector = happnConnector
		request = query
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		assert(connector.isConnected)
		fetchNextPage(currentOffset: 0)
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var users = [HappnUser]()
	
	private func fetchNextPage(currentOffset: Int) {
		let limit = 500
		var urlComponents = URLComponents(url: URL(string: "api/search-clients", relativeTo: connector.baseURL)!, resolvingAgainstBaseURL: true)!
		urlComponents.queryItems = [
			URLQueryItem(name: "offset",   value: String(currentOffset)),
			URLQueryItem(name: "limit",    value: String(limit)),
			URLQueryItem(name: "fields",   value: "id,first_name,last_name,acl,login,nickname"),
			URLQueryItem(name: "is_admin", value: "1")
		]
		if let r = request {urlComponents.queryItems!.append(URLQueryItem(name: "term", value: r))}
		
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .useDefaultKeys
		let op = AuthenticatedJSONOperation<HappnApiResult<[HappnUser]>>(url: urlComponents.url!, authenticator: connector.authenticate, decoder: decoder)
		op.completionBlock = {
			guard let o = op.result.successValue else {
				self.result = .failure(op.finalError ?? NSError(domain: "com.happn.officectl", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown error while fetching the users"]))
				self.baseOperationEnded()
				return
			}
			guard o.success else {
				self.result = .failure(NSError(domain: "com.happn.officectl.happn", code: o.error_code, userInfo: [NSLocalizedDescriptionKey: o.error ?? "Unknown error while fetching the users"]))
				return self.baseOperationEnded()
			}
			
			let users = o.data ?? []
			self.users.append(contentsOf: users)
			if users.count >= limit/2 {self.fetchNextPage(currentOffset: currentOffset + limit)}
			else                      {self.result = .success(self.users); self.baseOperationEnded()}
		}
		op.start()
	}
	
}
