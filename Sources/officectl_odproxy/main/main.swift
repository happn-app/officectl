/*
 * main.swift
 * officectl
 *
 * Created by François Lamboley on 10/07/2019.
 */

import Foundation

import LegibleError
import OfficeKit
import Vapor



do {
	let application = try app(.detect())
	defer {application.shutdown()}
	try application.run()
}
catch {
	print("Error creating or running the App.", to: &stderrStream)
	print("   error \(error.legibleLocalizedDescription)", to: &stderrStream)
	exit(Int32((error as NSError).code))
}
