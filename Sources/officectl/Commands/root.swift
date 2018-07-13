/*
 * root.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation
import Security

import Guaka
import RetryingOperation



class RootOperation : CommandOperation {
	
	override func startBaseOperation(isRetry: Bool) {
		command.fail(statusCode: 1, errorMessage: "Please choose a command verb")
	}
	
	override var isAsynchronous: Bool {
		return false
	}
	
}
