/*
 * LinkifyOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 09/08/2018.
 */

import Foundation

import Crypto
import RetryingOperation



public class LinkifyOperation : RetryingOperation {
	
	public let folderURL: URL
	public let stopOnErrors: Bool
	
	/** The errors that occurred during the run by URL (if any). Only meaningful
	when the run has finished. If stopOnErrors is true, there will be at most one
	entry in this dictionary. */
	public var errors: [URL: Error] {
		return errorsContainer.errors
	}
	
	public init(folderURL furl: URL, stopOnErrors flag: Bool = true) throws {
		folderURL = furl
		
		let ec = errorsContainer
		let handler = { (_ url: URL, _ error: Error) -> Bool in
			ec.errors[url] = error
			return !flag
		}
		let options: FileManager.DirectoryEnumerationOptions
		#if !os(Linux)
			options = .skipsHiddenFiles
		#else
			options = []
		#endif
		guard let e = FileManager.default.enumerator(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: options, errorHandler: handler) else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot enumerate URL \(folderURL)"])
		}
		
		directoryEnumerator = e
		stopOnErrors = flag
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		defer {baseOperationEnded()}
		
		var mustStop = false
		for f in directoryEnumerator {
			withAutoReleasePool{
				let curFileURL = f as! URL
				
				do {
					/* Let's make sure we are not treating a directory. */
					#if !os(Linux)
						guard !(try curFileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? true) else {
							return /* Return from autoreleasepool. Effectively continues to next file from enumerator. */
						}
					#else
						var isDir = ObjCBool(false)
						guard FileManager.default.fileExists(atPath: curFileURL.path, isDirectory: &isDir), !isDir.boolValue else {
							return /* Return from autoreleasepool. Effectively continues to next file from enumerator. */
						}
					#endif
					
					let data = try Data(contentsOf: curFileURL, options: Data.ReadingOptions.mappedIfSafe)
					let hash = try MD5.hash(data)
					if let matchURL = hashesToPaths[hash] {
						/* We found a (potential) match! */
						let data2 = try Data(contentsOf: matchURL, options: NSData.ReadingOptions.mappedIfSafe)
						if data == data2 {
							try FileManager.default.removeItem(at: curFileURL)
							try FileManager.default.linkItem(at: matchURL, to: curFileURL)
						} else {
							print("Found MD5 collision between \(matchURL) and \(curFileURL)!")
						}
					} else {
						hashesToPaths[hash] = curFileURL
					}
				} catch {
					errorsContainer.errors[curFileURL] = error
					mustStop = stopOnErrors
				}
			}
			guard !mustStop else {break}
		}
	}
	
	public override var isAsynchronous: Bool {
		return false
	}
	
	/* ***************
      MARK: - Private
	   *************** */
	
	private class ErrorsContainer {
		
		var errors = [URL: Error]()
		
	}
	
	private let directoryEnumerator: FileManager.DirectoryEnumerator
	private let errorsContainer = ErrorsContainer() /* To be able to define the directory enumerator directly in init with its completion handler */
	
	private var hashesToPaths = [Data: URL]()
	
}
