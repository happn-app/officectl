/*
 * SearchGoogleUsersOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2018/07/17.
 */

import Foundation

import HasResult
import RetryingOperation
import URLRequestOperation



/* See <https://github.com/happn-app/RetryingOperation/blob/123eafbc84db6b1bbcab6849882de2ccd1f6e60e/Sources/RetryingOperation/WrappedRetryingOperation.swift#L36>
 *  for more info about the unchecked Sendable conformance. */
extension SearchGoogleUsersOperation : @unchecked Sendable {}

/* <https://developers.google.com/admin-sdk/directory/v1/reference/users/list> */
public final class SearchGoogleUsersOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = [GoogleUser]
	
	public static let scopes = Set(arrayLiteral: "https://www.googleapis.com/auth/admin.directory.group", "https://www.googleapis.com/auth/admin.directory.user.readonly")
	
	public let connector: GoogleJWTConnector
	public let request: GoogleUserSearchRequest
	
	public private(set) var result = Result<[GoogleUser], Error>.failure(OperationIsNotFinishedError())
	
	public init(searchedDomain d: String, query: String? = nil, googleConnector: GoogleJWTConnector) {
		connector = googleConnector
		request = GoogleUserSearchRequest(domain: d, query: query)
	}
	
	public override func startBaseOperation(isRetry: Bool) {
//		assert(connector.isConnected)
		Task{
			result = await Result{
				var token: String?
				var res = [GoogleUser]()
				repeat {
					let newUsersList = try await fetchNextPage(nextPageToken: token)
					token = newUsersList.nextPageToken
					res += newUsersList.users ?? []
				} while token != nil
				return res
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
	
	
	private func fetchNextPage(nextPageToken: String?) async throws -> GoogleUsersList {
		let queryParams = RequestQuery(domain: request.domain, query: request.query, pageToken: nextPageToken)
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .customISO8601
		let op = try URLRequestDataOperation<GoogleUsersList>.forAPIRequest(
			url: URL(string: "https://www.googleapis.com/admin/directory/v1/users")!, urlParameters: queryParams,
			decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		)
		return try await op.startAndGetResult().result
		
		struct RequestQuery : Encodable {
			var domain: String
			var query: String?
			var pageToken: String?
		}
	}
	
}


public struct GoogleUserSearchRequest : Sendable {
	
	let domain: String
	/**
	 The query for the search.
	 
	 If `nil`, the search will return all users in the given domain.
	 No validation on the query is done.
	 
	 The format is described here: <https://developers.google.com/admin-sdk/directory/v1/guides/search-users>. */
	let query: String?
	
	public init(domain d: String, query q: String?) {
		query = q
		domain = d
	}
	
}
