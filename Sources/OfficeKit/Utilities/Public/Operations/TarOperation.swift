/*
 * TarOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/08/2018.
 */

import Foundation

import RetryingOperation



public class TarOperation : RetryingOperation {
	
	public let sourceBase: URL
	public let sources: [String] /* MUST be non-empty (ensured at init with an assert) */
	public let destination: URL
	
	public let compress: Bool
	public let deleteSourcesOnSuccess: Bool
	
	public private(set) var tarError: Error?
	/** Always empty if there was a tar error! (sources are not deleted in case of a tar error) */
	public private(set) var sourceDeletionErrors = [URL: Error]()
	
	public init(sources s: [String], relativeTo relativeSource: URL, destination d: URL, compress cprs: Bool, deleteSourcesOnSuccess del: Bool) {
		assert(s.count > 0)
		
		sourceBase = relativeSource
		sources = s
		compress = cprs
		destination = d
		deleteSourcesOnSuccess = del
	}
	
	public override var isAsynchronous: Bool {
		return false
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		defer {self.baseOperationEnded()}
		
		guard sources.count > 0 else {return}
		
		let destinationPath = destination.path
		
		let process = Process()
#if !os(Linux)
		process.standardInput = FileHandle.nullDevice
		process.standardError = FileHandle.nullDevice /* TODO: Retrieve stderr to have more context when tar fails... */
		process.standardOutput = FileHandle.nullDevice
#endif
		
#if !os(Linux)
		/* BSD tar */
		process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
		process.arguments = ["-C", sourceBase.path, "-c" + (compress ? "j" : "") + "f", destinationPath] + sources
#else
		/* GNU tar */
		process.executableURL = URL(fileURLWithPath: "/bin/tar")
		process.arguments = ["-C", sourceBase.path, "-c" + (compress ? "j" : "") + "f", destinationPath] + sources
#endif
		
		do {try process.run()}
		catch {tarError = error; return}
		process.waitUntilExit()
		
		guard process.terminationStatus == 0 else {
			tarError = NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "tar exited with code \(process.terminationStatus) (sources: \(sources), destination: \(destinationPath))"])
			return
		}
		
		if deleteSourcesOnSuccess {
			/* Let’s delete the sources */
			for p in sources {
				let u = URL(fileURLWithPath: p, relativeTo: sourceBase)
				do    {try FileManager.default.removeItem(at: u)}
				catch {sourceDeletionErrors[u] = error}
			}
		}
	}
	
}
