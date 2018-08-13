/*
 * GitHubRepositorySearchOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 18/07/2018.
 */

import Foundation

import AsyncOperationResult
import RetryingOperation



public class GitHubRepositorySearchOperation : RetryingOperation {
	
	public let searchedOrganisation: String
	public let connector: GitHubJWTConnector
	
	public private(set) var result = AsyncOperationResult<[GitHubRepository]>.error(OperationIsNotFinishedError())
	
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
		#if !os(Linux)
			decoder.keyDecodingStrategy = .convertFromSnakeCase
		#endif
		let op = AuthenticatedJSONOperation<[GitHubRepository]>(url: urlComponents.url!, authenticator: connector.authenticate, decoder: decoder)
		op.completionBlock = {
			guard let o = op.decodedObject else {
				self.result = .error(op.finalError ?? NSError(domain: "com.happn.officectl", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown error while fetching the repositories"]))
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
