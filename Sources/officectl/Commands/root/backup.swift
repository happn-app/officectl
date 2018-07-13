/*
 * backup.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Guaka
import Foundation



class BackupOperation : CommandOperation {
	
	override func startBaseOperation(isRetry: Bool) {
		command.fail(statusCode: 1, errorMessage: "Please choose what to backup")
	}
	
	override var isAsynchronous: Bool {
		return false
	}
	
}
