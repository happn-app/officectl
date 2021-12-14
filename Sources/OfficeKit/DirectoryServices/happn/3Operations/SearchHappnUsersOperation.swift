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
				/* Get users from email search */
				repeat {
					let usersAtPage = try await searchResults(for: Request(offset: curOffset, limit: limit, fullTextSearchWithAllTerms: email))
					nUsersAtCurPage = usersAtPage.count
					users += usersAtPage
					curOffset += limit
				} while nUsersAtCurPage >= limit/2
				if let email = email {
					/* Get users from ids search */
					curOffset = 0
					repeat {
						let usersAtPage = try await searchResults(for: Request(offset: curOffset, limit: limit, ids: [email]))
						nUsersAtCurPage = usersAtPage.count
						users += usersAtPage
						curOffset += limit
					} while nUsersAtCurPage >= limit/2
				}
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
	
	private func searchResults(for request: Request) async throws -> [HappnUser] {
		return try await URLRequestDataOperation<HappnApiResult<[HappnUser]>>.forAPIRequest(
			url: connector.baseURL.appending("api", "v1", "users-search"),
			urlParameters: ["fields": "id,first_name,last_name,acl,login,nickname,type"],
			httpBody: request,
			requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		).startAndGetResult().result.data ?? []
	}
	
	private struct Request : Encodable {
		var offset: Int?
		var limit: Int?
		var isAdmin: Bool = true
		var ids: [String]?
		var fullTextSearchWithAllTerms: String?
		private enum CodingKeys : String, CodingKey {
			case offset, limit
			case isAdmin = "is_admin"
			case ids, fullTextSearchWithAllTerms = "full_text_search_with_all_terms"
		}
	}
	
}
