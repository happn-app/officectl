/*
 * CloneGitHubRepoOperation.swift
 * officectl
 *
 * Created by François Lamboley on 27/06/2018.
 */

import Foundation

import RetryingOperation



class CloneGitHubRepoOperation : RetryingOperation {
	
	let repoName: String
	let repoCloneURL: String
	let destinationURL: URL
	
	/** Clone error. Only makes sense when the operation is finished. */
	var cloneError: Error?
	
	convenience init(in containerURL: URL, repoFullName name: String, accessToken: String) {
		let url = URL(fileURLWithPath: name.trimmingCharacters(in: CharacterSet(charactersIn: "/")), isDirectory: true, relativeTo: containerURL)
		self.init(destinationURL: url, repoFullName: name, accessToken: accessToken)
	}
	
	init(destinationURL u: URL, repoFullName: String, accessToken: String) {
		repoName = repoFullName
		repoCloneURL = "https://x-access-token:\(accessToken)@github.com/\(repoFullName).git"
		destinationURL = u
	}
	
	override var isAsynchronous: Bool {
		return false
	}
	
	override func startBaseOperation(isRetry: Bool) {
		defer {baseOperationEnded()}
		
		var isDir = ObjCBool(booleanLiteral: false)
		let destinationExists = FileManager.default.fileExists(atPath: destinationURL.path, isDirectory: &isDir)
		guard !destinationExists || isDir.boolValue else {
			cloneError = NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Destination \(destinationURL.path) exists and is a file. Cannot use for cloning repository \(repoName)."])
			baseOperationEnded()
			return
		}
		
		let process = Process()
		process.standardInput = FileHandle.nullDevice
		process.standardOutput = FileHandle.nullDevice
		
		process.launchPath = "/usr/bin/git"
		if !destinationExists {
			process.arguments = ["clone", "--quiet", "--mirror", repoCloneURL, destinationURL.path]
		} else {
			/* The repository already exists. We must modify the config to update
			 * the remote for the URL. We could modify the config file directly,
			 * but let's do things properly and call git for that. */
			let updateRemoteProcess = Process()
			updateRemoteProcess.standardInput = FileHandle.nullDevice
			updateRemoteProcess.standardOutput = FileHandle.nullDevice
			updateRemoteProcess.launchPath = process.launchPath
			updateRemoteProcess.arguments = ["-C", destinationURL.path, "remote", "set-url", "origin", repoCloneURL]
			updateRemoteProcess.launch()
			updateRemoteProcess.waitUntilExit()
			guard updateRemoteProcess.terminationStatus == 0 else {
				cloneError = NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "git exited with code \(process.terminationStatus) when updating the remote"])
				return
			}
			
			process.arguments = ["-C", destinationURL.path, "remote", "update", "--prune"]
			process.standardError = FileHandle.nullDevice /* Did not find the option to tell git to be quiet for this one... :( */
		}
		
		process.launch()
		process.waitUntilExit()
		
		if process.terminationStatus != 0 {
			cloneError = NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "git exited with code \(process.terminationStatus)"])
		}
	}
	
}
