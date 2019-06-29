/*
 * github.swift
 * officectl
 *
 * Created by François Lamboley on 27/06/2018.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit



func backupGitHub(flags f: Flags, arguments args: [String], context: CommandContext) throws -> Future<Void> {
	let asyncConfig: AsyncConfig = try context.container.make()
	let officeKitServiceProvider: OfficeKitServiceProvider = try context.container.make()
	
	let gitHubService: GitHubService = try officeKitServiceProvider.getDirectoryService(id: f.getString(name: "service-id"), container: context.container)
	let gitHubConfig = gitHubService.serviceConfig
	
	let orgName = try nil2throw(f.getString(name: "orgname"), "orgname")
	let destinationFolderURL = try URL(fileURLWithPath: nil2throw(f.getString(name: "destination"), "destination"), isDirectory: true)
	
	let gitHubConnector = try GitHubJWTConnector(key: gitHubConfig.connectorSettings)
	let f = gitHubConnector.connect(scope: (), asyncConfig: asyncConfig)
	.then{ _ -> Future<[GitHubRepository]> in
		context.console.info("Fetching repositories list from GitHub...")
		let searchOp = GitHubRepositorySearchOperation(searchedOrganisation: orgName, gitHubConnector: gitHubConnector)
		return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.operationQueue)
	}
	.then{ repositories -> Future<Set<String>> in
		let promise: EventLoopPromise<Set<String>> = asyncConfig.eventLoop.newPromise()
		asyncConfig.dispatchQueue.async{
			let repositoryNames = Set(repositories.map{ $0.fullName })
			
			context.console.info("Found \(repositoryNames.count) repositories")
			context.console.info("Searching for obsolete backed-up repositories...")
			defer {promise.succeed(result: repositoryNames)} /* Even if we can't remove obsolete repositories, we do not fail this promise. */
			
			iterateLevel2Sync(in: destinationFolderURL, handler: { (container, folder, currentFolderURL) in
				guard currentFolderURL.pathExtension == "git" || currentFolderURL.lastPathComponent == ".DS_Store" else {
					context.console.warning("found path \"\(currentFolderURL.path)\" which does not have a \"git\" extension; not deleting"/*, to: &stderrStream*/)
					return
				}
				
				let repoName = container + "/" + (folder as NSString).deletingPathExtension
				if !repositoryNames.contains(repoName) {
					context.console.info("   Deleting \(currentFolderURL.path)")
					if (try? FileManager.default.removeItem(at: currentFolderURL)) == nil {
						context.console.error("cannot delete URL \(currentFolderURL)"/*, to: &stderrStream*/)
					}
				}
			})
		}
		return promise.futureResult
	}
	.then{ repositoryNames -> Future<([FutureResult<Void>], Set<String>)> in
		context.console.info("Updating clones...")
		let q = OperationQueue(); q.maxConcurrentOperationCount = 7 /* We do not use the default operation queue from async config. Indeed, we are launching one sub-process per operation. We do not want a configuration suited for threads, we want one suited for launching subprocesses. */
		let operations = repositoryNames.map{ CloneGitHubRepoOperation(in: destinationFolderURL, repoFullName: $0, accessToken: gitHubConnector.token!) }
		return asyncConfig.eventLoop
			.executeAll(operations, queue: q, resultRetriever: { o -> Void in try throwIfError(o.cloneError) })
			.and(result: repositoryNames)
	}
	.then{ r -> Future<Void> in
		let (operationResults, repositoryNames) = r
		
		/* Let's check we have all the repositories backed-up */
		var localRepoNames = Set<String>()
		iterateLevel2Sync(in: destinationFolderURL, handler: { (container, folder, currentFolderURL) in
			guard currentFolderURL.pathExtension == "git" else {return}
			localRepoNames.insert(container + "/" + (folder as NSString).deletingPathExtension)
		})
		let missingRepoNames = repositoryNames.subtracting(localRepoNames)
		if missingRepoNames.count > 0 {
			context.console.warning("the following repositories have not been backed up: \(missingRepoNames)"/*, to: &stderrStream*/)
		}
		
		let errors = operationResults.compactMap{ $0.error }
		guard errors.count == 0 else {
			return asyncConfig.eventLoop.newFailedFuture(error: NSError(domain: "com.happn.officectl", code: 3, userInfo: [NSLocalizedDescriptionKey: "Got the following errors while backing up the repositories" + errors.reduce("", { $0 + "\n   " + $1.legibleLocalizedDescription })]))
		}
		
		return asyncConfig.eventLoop.newSucceededFuture(result: ())
	}
	return f
}

/// Iterate over paths matching the "\*/\*" glob in baseFolder.
private func iterateLevel2Sync(in baseFolder: URL, handler: (_ containerFolderName: String, _ currentElementName: String, _ fullURL: URL) -> Void) {
	guard let folders = try? FileManager.default.contentsOfDirectory(atPath: baseFolder.path) else {return}
	for f in folders {
		let currentContainerURL = URL(fileURLWithPath: f, isDirectory: true, relativeTo: baseFolder)
		guard let subfolders = try? FileManager.default.contentsOfDirectory(atPath: currentContainerURL.path) else {
			continue
		}
		
		for s in subfolders {
			handler(f, s, URL(fileURLWithPath: s, isDirectory: true, relativeTo: currentContainerURL))
		}
	}
}
