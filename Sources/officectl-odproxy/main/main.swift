/*
 * main.swift
 * officectl
 *
 * Created by François Lamboley on 2019/07/10.
 */

import Foundation

import LegibleError
import OfficeKit2
import Vapor



do {
	let application = try app(.detect())
	defer {application.shutdown()}
	try application.run()
	
} catch {
	let errorMsg = "Error creating or running the App: \(error.legibleLocalizedDescription).\n"
	if #available(macOS 10.15.4, *),
		(try? FileHandle.standardError.write(contentsOf: Data(errorMsg.utf8))) != nil {
	} else {
		/* Either OS too old, or write failed; we print. */
		print(errorMsg)
	}
	exit(Int32((error as NSError).code))
}
