/*
 * github.swift
 * officectl
 *
 * Created by François Lamboley on 27/06/2018.
 */

import Foundation

import OfficeKit

import Guaka



class BackupGitHubOperation : CommandOperation {
	
	override init(command c: Command, flags f: Flags, arguments args: [String]) {
		do {
			gitHubConnectorOperation = try GetConnectedGitHubConnector(flags: f)
		} catch {
			c.fail(statusCode: (error as NSError).code, errorMessage: error.localizedDescription)
		}
		
		cloneOperationQueue = OperationQueue()
		cloneOperationQueue.maxConcurrentOperationCount = 7
		
		destinationFolderURL = URL(fileURLWithPath: f.getString(name: "destination")!, isDirectory: true)
		
		super.init(command: c, flags: f, arguments: args)
		
		addDependency(gitHubConnectorOperation)
	}
	
	override var isAsynchronous: Bool {
		return true
	}
	
	override func startBaseOperation(isRetry: Bool) {
		print("Fetching repositories list from GitHub...")
		fetchRepos(from: 0)
	}
	
	private let destinationFolderURL: URL
	private let cloneOperationQueue: OperationQueue
	private var cloneOperations = [CloneGitHubRepoOperation]()
	private let gitHubConnectorOperation: GetConnectedGitHubConnector
	private var gitHubConnector: GitHubJWTConnector {return gitHubConnectorOperation.connector}
	
	private func fetchRepos(from pageNumber: Int) {
		let orgName = flags.getString(name: "orgname")!
		var urlComponents = URLComponents(string: "https://api.github.com/orgs/\(orgName)/repos")!
		urlComponents.queryItems = [URLQueryItem(name: "type", value: "all"), URLQueryItem(name: "page", value: String(pageNumber))]
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		let op = AuthenticatedJSONOperation<[GitHubRepository]>(url: urlComponents.url!, authenticator: gitHubConnector.authenticate, decoder: decoder)
		op.completionBlock = {
			guard let o = op.decodedObject else {
				self.command.fail(statusCode: 1, errorMessage: op.finalError?.localizedDescription ?? "Unknown error while fetching the repositories")
			}
			
			let currentCloneOperations = o.map{ CloneGitHubRepoOperation(in: self.destinationFolderURL, repoFullName: $0.fullName, accessToken: self.gitHubConnector.token!) }
			self.cloneOperations.append(contentsOf: currentCloneOperations)
			if o.count > 0 {self.fetchRepos(from: pageNumber+1)}
			else           {self.launchClonesAndDeleteObsoleteRepositories()}
		}
		op.start()
	}
	
	private func launchClonesAndDeleteObsoleteRepositories() {
		assert(!Thread.isMainThread)
		
		print("Found \(cloneOperations.count) repositories")
		print("Searching for deleted backed-up repositories...")
		
		let repositoryNames = Set(cloneOperations.map{ $0.repoName })
		if let folders = try? FileManager.default.contentsOfDirectory(atPath: destinationFolderURL.path) {
			for f in folders {
				if let subfolders = try? FileManager.default.contentsOfDirectory(atPath: URL(fileURLWithPath: f, relativeTo: destinationFolderURL).path) {
					for s in subfolders {
						let repoName = "\(f)/\(s)"
						let repoFullLocalURL = URL(fileURLWithPath: repoName, relativeTo: destinationFolderURL)
						if !repositoryNames.contains(repoName) {
							print("   Found \(repoName); deleting")
							if (try? FileManager.default.removeItem(at: repoFullLocalURL)) == nil {
								print("Error deleting URL \(repoFullLocalURL)", to: &stderrStream)
							}
						}
					}
				}
			}
		}
		
		print("Updating clones...")
		
		cloneOperationQueue.addOperations(cloneOperations, waitUntilFinished: true)
		let numberOfCloneErrors = cloneOperations.reduce(0, { $0 + ($1.cloneError != nil ? 1 : 0) })
		guard numberOfCloneErrors == 0 else {
			command.fail(statusCode: 1, errorMessage: "\(numberOfCloneErrors) \(numberOfCloneErrors == 1 ? "repository" : "repositories") failed to clone")
		}
		self.baseOperationEnded()
	}
	
}
