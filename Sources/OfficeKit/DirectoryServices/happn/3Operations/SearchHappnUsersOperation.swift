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
import HasResult
import RetryingOperation
import URLRequestOperation



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
		Task{
			result = await Result{
				let limit = 500
				var curOffset = 0
				var nUsersAtCurPage = 0
				var users = [HappnUser]()
				repeat {
					let reposAtPage = try await fetchPage(offset: curOffset, limit: limit)
					nUsersAtCurPage = reposAtPage.count
					users += reposAtPage
					curOffset += limit
				} while nUsersAtCurPage >= limit/2
				return users
			}
			baseOperationEnded()
		}
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private func fetchPage(offset: Int, limit: Int) async throws -> [HappnUser] {
		struct RequestBody : Encodable {
			var offset: Int?
			var limit: Int?
			var isAdmin: Bool = true
			var fullTextSearchWithAllTerms: String?
			private enum CodingKeys : String, CodingKey {
				case offset, limit
				case isAdmin = "is_admin"
				case fullTextSearchWithAllTerms = "full_text_search_with_all_terms"
			}
		}
		let op = try URLRequestDataOperation<HappnApiResult<[HappnUser]>>.forAPIRequest(
			baseURL: connector.baseURL, path: "api/v1/users-search",
			urlParameters: ["fields": "id,first_name,last_name,acl,login,nickname,type"],
			httpBody: RequestBody(offset: offset, limit: limit, fullTextSearchWithAllTerms: email),
			requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		)
		return try await op.startAndGetResult().result.data ?? []
	}
	
}
