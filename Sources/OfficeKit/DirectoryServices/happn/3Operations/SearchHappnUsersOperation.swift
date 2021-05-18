/*
 * SearchHappnUsersOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 29/08/2019.
 */

import Foundation
#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

import GenericJSON
import RetryingOperation



public final class SearchHappnUsersOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = [HappnUser]
	
	public static let scopes = Set(arrayLiteral: "admin_read", "admin_search_user")
	
	public let connector: HappnConnector
	public let email: String?
	
	public private(set) var result = Result<[HappnUser], Error>.failure(OperationIsNotFinishedError())
	
	public init(email e: String? = nil, happnConnector: HappnConnector) {
		connector = happnConnector
		email = e
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
		do {
			let limit = 500
			var urlComponents = URLComponents(url: URL(string: "api/v1/users-search", relativeTo: connector.baseURL)!, resolvingAgainstBaseURL: true)!
			urlComponents.queryItems = [
				URLQueryItem(name: "fields", value: "id,first_name,last_name,acl,login,nickname,type"),
			]
			var requestBody = JSON.object([
				"offset": .number(Float(currentOffset)),
				"limit": .number(Float(limit)),
				"is_admin": true
			])
			if let e = email {requestBody = requestBody.merging(with: JSON.object(["full_text_search_with_all_terms": .string(e)]))}
			var urlRequest = URLRequest(url: urlComponents.url!)
			urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
			urlRequest.httpBody = try JSONEncoder().encode(requestBody)
			urlRequest.httpMethod = "POST"
			
			let decoder = JSONDecoder()
			decoder.keyDecodingStrategy = .useDefaultKeys
			let op = AuthenticatedJSONOperation<HappnApiResult<[HappnUser]>>(request: urlRequest, authenticator: connector.authenticate, decoder: decoder)
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
		} catch {
			result = .failure(error)
			baseOperationEnded()
		}
	}
	
}
