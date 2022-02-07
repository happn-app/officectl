/*
 * GitHubRepositorySearchOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 18/07/2018.
 */

import Foundation

import HasResult
import RetryingOperation



public final class GitHubRepositorySearchOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = [GitHubRepository]
	
	public let searchedOrganisation: String
	public let connector: GitHubJWTConnector
	
	public private(set) var result = Result<[GitHubRepository], Error>.failure(OperationIsNotFinishedError())
	
	public init(searchedOrganisation orgname: String, gitHubConnector: GitHubJWTConnector) {
		assert(gitHubConnector.isConnected)
		searchedOrganisation = orgname
		connector = gitHubConnector
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		fetchRepos(from: 0)
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var repositories = [GitHubRepository]()
	
	private func fetchRepos(from pageNumber: Int) {
		var urlComponents = URLComponents(string: "https://api.github.com/orgs/\(searchedOrganisation)/repos")!
		urlComponents.queryItems = [URLQueryItem(name: "type", value: "all"), URLQueryItem(name: "page", value: String(pageNumber))]
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		let op = AuthenticatedJSONOperation<[GitHubRepository]>(url: urlComponents.url!, authenticator: connector.authenticate, decoder: decoder)
		op.completionBlock = {
			guard let o = op.result.successValue else {
				self.result = .failure(op.finalError ?? NSError(domain: "com.happn.officectl", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown error while fetching the repositories"]))
				self.baseOperationEnded()
				return
			}
			
			self.repositories.append(contentsOf: o)
			if o.count > 0 {self.fetchRepos(from: pageNumber+1)}
			else           {self.result = .success(self.repositories); self.baseOperationEnded()}
		}
		op.start()
	}
	
}
