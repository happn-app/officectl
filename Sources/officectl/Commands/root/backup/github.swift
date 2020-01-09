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



func backupGitHub(flags f: Flags, arguments args: [String], context: CommandContext, app: Application) throws -> EventLoopFuture<Void> {
	let officeKitConfig = app.officeKitConfig
	let eventLoop = try app.services.make(EventLoop.self)
	
	let serviceId = f.getString(name: "service-id")
	let gitHubConfig: GitHubServiceConfig = try officeKitConfig.getServiceConfig(id: serviceId)
	
	let orgName = try nil2throw(f.getString(name: "orgname"), "orgname")
	let destinationFolderURL = try URL(fileURLWithPath: nil2throw(f.getString(name: "downloads-destination-folder"), "downloads-destination-folder"), isDirectory: true)
	
	try app.auditLogger.log(action: "Backing up GitHub w/ service \(serviceId ?? "<inferred service>"), organization name \(orgName) to \(destinationFolderURL).", source: .cli)
	
	let gitHubConnector = try GitHubJWTConnector(key: gitHubConfig.connectorSettings)
	let f = gitHubConnector.connect(scope: (), eventLoop: eventLoop)
	.flatMap{ _ -> EventLoopFuture<[GitHubRepository]> in
		context.console.info("Fetching repositories list from GitHub...")
		let searchOp = GitHubRepositorySearchOperation(searchedOrganisation: orgName, gitHubConnector: gitHubConnector)
		return EventLoopFuture<[GitHubRepository]>.future(from: searchOp, on: eventLoop)
	}
	.flatMap{ repositories -> EventLoopFuture<Set<String>> in
		let promise: EventLoopPromise<Set<String>> = eventLoop.makePromise()
		defaultDispatchQueueForFutureSupport.async{
			let repositoryNames = Set(repositories.map{ $0.fullName })
			
			context.console.info("Found \(repositoryNames.count) repositories")
			context.console.info("Searching for obsolete backed-up repositories...")
			defer {promise.succeed(repositoryNames)} /* Even if we can't remove obsolete repositories, we do not fail this promise. */
			
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
	.flatMap{ repositoryNames -> EventLoopFuture<([Result<Void, Error>], Set<String>)> in
		context.console.info("Updating clones...")
		let q = OperationQueue(); q.maxConcurrentOperationCount = 7 /* We do not use the default operation queue from async config. Indeed, we are launching one sub-process per operation. We do not want a configuration suited for threads, we want one suited for launching subprocesses. */
		let operations = repositoryNames.map{ CloneGitHubRepoOperation(in: destinationFolderURL, repoFullName: $0, accessToken: gitHubConnector.token!) }
		return EventLoopFuture<[Result<Void, Error>]>
			.executeAll(operations, on: eventLoop, queue: q, resultRetriever: { o -> Void in try throwIfError(o.cloneError) })
			.and(value: repositoryNames)
	}
	.flatMapThrowing{ r in
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
		
		let errors = operationResults.compactMap{ $0.failureValue }
		guard errors.count == 0 else {
			throw NSError(domain: "com.happn.officectl", code: 3, userInfo: [NSLocalizedDescriptionKey: "Got the following errors while backing up the repositories" + errors.reduce("", { $0 + "\n   " + $1.legibleLocalizedDescription })])
		}
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
