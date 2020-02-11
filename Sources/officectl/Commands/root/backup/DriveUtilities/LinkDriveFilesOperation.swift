/*
 * LinkDriveFilesOperation.swift
 * officectl
 *
 * Created by François Lamboley on 11/02/2020.
 */

import Foundation

import OfficeKit
import RetryingOperation



private class LinkDriveFilesOperation : RetryingOperation, HasResult {
	
	typealias ResultType = Void
	
	let logFile: LogFile
	
	private(set) var links = [(source: URL, destination: URL, fileId: String)]() {
		willSet {assert(!isFinished && !isExecuting)}
	}
	
	private(set) var result: Result<Void, Error> = .failure(OperationIsNotFinishedError())
	
	init(logFile lf: LogFile) {
		logFile = lf
		
		super.init()
	}
	
	func addLink(source: URL, destination: URL, fileId: String) {
		linksSyncQueue.sync{ links.append((source: source, destination: destination, fileId: fileId)) }
	}
	
	override func startBaseOperation(isRetry: Bool) {
		defer {baseOperationEnded()}
		
		let fm = FileManager.default
		
		var errors = [Error]()
		var destinations = Set<URL>()
		links.map{ baseLink -> (source: URL, destination: URL, fileId: String) in
			var hasChanged = false
			var newLink: (source: URL, destination: URL, fileId: String) = baseLink
			while !destinations.insert(newLink.destination).inserted {
				/* The destination was taken. Let’s find a non-existing one. */
				newLink = (source: baseLink.source, destination: baseLink.destination, fileId: baseLink.fileId)
				hasChanged = true
			}
			if hasChanged {
				_ = try? logFile.logCSVLine([newLink.fileId, "linking_warning", "Expected destination \(baseLink.destination.path) was already taken; renamed to \(newLink.destination.path)"])
			}
			return newLink
		}
		.forEach{ link in
			do {
				try fm.linkItem(at: link.source, to: link.destination)
			} catch {
				errors.append(error)
			}
		}
		
		if !errors.isEmpty {result = .failure(ErrorCollection(errors))}
		else               {result = .success(())}
	}
	
	override var isAsynchronous: Bool {
		return false
	}
	
	private let linksSyncQueue = DispatchQueue(label: "com.happn.officectl.linksdrivefilesqueue")
	
}
