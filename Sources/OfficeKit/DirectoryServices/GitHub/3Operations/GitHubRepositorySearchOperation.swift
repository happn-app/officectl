/*
 * GitHubRepositorySearchOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 18/07/2018.
 */

import Foundation

import HasResult
import RetryingOperation
import URLRequestOperation



public final class GitHubRepositorySearchOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = [GitHubRepository]
	
	public let searchedOrganisation: String
	public let connector: GitHubJWTConnector
	
	public private(set) var result = Result<[GitHubRepository], Error>.failure(OperationIsNotFinishedError())
	
	public init(searchedOrganisation orgname: String, gitHubConnector: GitHubJWTConnector) {
//		assert(gitHubConnector.isConnected)
		searchedOrganisation = orgname
		connector = gitHubConnector
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		Task{
			result = await Result{
				var curPage = 0
				var nReposAtCurPage = 0
				var repos = [GitHubRepository]()
				repeat {
					let reposAtPage = try await fetchRepos(at: curPage)
					nReposAtCurPage = reposAtPage.count
					repos += reposAtPage
					curPage += 1
				} while nReposAtCurPage > 0
				return repos
			}
			baseOperationEnded()
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private func fetchRepos(at pageNumber: Int) async throws -> [GitHubRepository] {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		
		let op = try URLRequestDataOperation<[GitHubRepository]>.forAPIRequest(
			url: URL(string: "https://api.github.com")!.appending("orgs", searchedOrganisation, "repos"), urlParameters: RequestParams(page: pageNumber),
			decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		)
		return try await op.startAndGetResult().result
		
		struct RequestParams : Encodable {
			var type = "all"
			var page: Int
		}
	}
	
}
