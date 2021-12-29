/*
 * LogFile.swift
 * officectl
 *
 * Created by François Lamboley on 2020/02/11.
 */

import Foundation



class LogFile {
	
	static let csvSep = ","
	
	convenience init(url: URL, csvHeader cells: [String]) throws {
		try self.init(url: url, header: Data((cells.map{ $0.csvCellValueWithSeparator(LogFile.csvSep) }.joined(separator: LogFile.csvSep) + "\n").utf8))
	}
	
	init(url: URL, header: Data? = nil) throws {
		let folder = url.deletingLastPathComponent()
		try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
		
		let fileExists = FileManager.default.fileExists(atPath: url.path)
		/* Not sure the explicit file creation is needed… */
		guard fileExists || FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil) else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create log file"])
		}
		
		guard let s = OutputStream(url: url, append: true) else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create log file"])
		}
		s.open()
		
		stream = s
		
		if !fileExists, let header = header {
			try logData(header)
		}
	}
	
	deinit {
		stream.close()
	}
	
	func logCSVLine(_ cells: [String]) throws {
		try logLine(cells.map{ $0.csvCellValueWithSeparator(LogFile.csvSep) }.joined(separator: LogFile.csvSep))
	}
	
	func logLine(_ line: String) throws {
		try logData(Data((line + "\n").utf8))
	}
	
	func logData(_ data: Data) throws {
		try syncQueue.sync{
			try data.withUnsafeBytes{ bytes in
				let n = bytes.count
				guard stream.write(bytes.bindMemory(to: UInt8.self).baseAddress!, maxLength: n) == n else {
					throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to write to log file"])
				}
			}
		}
	}
	
	private let syncQueue = DispatchQueue(label: "com.happn.officectl.logfilewritequeue")
	private let stream: OutputStream
	
}


/* ****************************************** */

private extension String {
	
	func csvCellValueWithSeparator(_ sep: String) -> String {
		guard sep.utf16.count == 1, sep != "\"", sep != "\n", sep != "\r" else {fatalError("Cannot use \"\(sep)\" as a CSV separator")}
		if rangeOfCharacter(from: CharacterSet(charactersIn: "\(sep)\"").union(.newlines)) != nil {
			/* Double quotes needed */
			let doubledDoubleQuotes = replacingOccurrences(of: "\"", with: "\"\"")
			return "\"\(doubledDoubleQuotes)\""
		} else {
			/* Double quotes not needed */
			return self
		}
	}
	
}
