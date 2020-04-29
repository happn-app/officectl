/*
 * AuditLogger.swift
 * officectl
 *
 * Created by François Lamboley on 04/08/2019.
 */

import Foundation

import GenericJSON
import OfficeKit
import Vapor



#warning("TODO: When I find one, use a FileLogger instead of manually writing to the file?")
class AuditLogger {
	
	enum ActionSource {
		
		case cli
		case api(user: LoggedInUser)
		case web
		
	}
	
	let destinationURL: URL?
	
	init(path: String?) throws {
		destinationURL = path.flatMap{ URL(fileURLWithPath: $0) }
		
		jsonEncoder = JSONEncoder()
		jsonEncoder.outputFormatting = [.sortedKeys]
		
		if let url = destinationURL {
			var isDir = ObjCBool(true)
			let fm = FileManager.default
			if !fm.fileExists(atPath: url.path, isDirectory: &isDir) {
				guard fm.createFile(atPath: url.path, contents: nil, attributes: nil) else {
					throw InternalError(message: "cannot create audit logs at path: \(url.path)")
				}
			} else if isDir.boolValue {
				throw InvalidArgumentError(message: "cannot create audit logs at path: \(url.path): path is a directory")
			}
		}
	}
	
	/** Log the given action in the destination path set when initing the logger.
	This method **can** throw by design. Because we’re doing audit logs, we want
	whatever action is taken to fail if it cannot be logged. */
	func log(action: String, source: ActionSource, file: String = #file, function: String = #function, line: UInt = #line, column: UInt = #column) throws {
		guard let destinationURL = destinationURL else {return}
		
		var loggedDict: [String: JSON] = [
			"date": JSON.string(dateFormatter.string(from: Date())),
			"action": JSON.string(action),
			"file": JSON.string(file),
			"function": JSON.string(function),
			"line": JSON.number(Float(line)),
			"column": JSON.number(Float(column))
		]
		switch source {
		case .cli: loggedDict["source"] = "cli"
		case .web: loggedDict["source"] = "web"
		case .api(user: let loggedInUser):
			loggedDict["source"] = "api"
			loggedDict["api_user"] = JSON.string(loggedInUser.user.taggedId.stringValue)
			loggedDict["api_user_is_admin"] = JSON.bool(loggedInUser.isAdmin)
		}
		let loggedData = try jsonEncoder.encode(JSON.object(loggedDict)) + Data("\n".utf8)
		
		/* Note: We open the file for each new log… for our load this will work
		 *       well enough; we may have to change that if we had more traffic. */
		let fh = try FileHandle.init(forWritingTo: destinationURL)
		defer {fh.closeFile()}
		
		fh.seekToEndOfFile()
		fh.write(loggedData)
		fh.synchronizeFile()
	}
	
	private let dateFormatter = ISO8601DateFormatter()
	private let jsonEncoder: JSONEncoder
	
}
