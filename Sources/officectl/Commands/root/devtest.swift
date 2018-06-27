/*
 * devtest.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Guaka
import Foundation



class DevTestOperation : CommandOperation {
	
	override func startBaseOperation(isRetry: Bool) {
		command.fail(statusCode: 1, errorMessage: "Please choose what to test")
	}
	
	override var isAsynchronous: Bool {
		return false
	}
	
}
