/*
 * sync.swift
 * officectl
 *
 * Created by François Lamboley on 13/07/2018.
 */

import Guaka
import Foundation



class SyncOperation : CommandOperation {
	
	override init(command c: Command, flags f: Flags, arguments args: [String]) {
		switch f.getString(name: "from")!.lowercased() {
		case "google": ()
		case "ldap": ()
		default: ()
		}
		
		super.init(command: c, flags: f, arguments: args)
	}
	
	override func startBaseOperation(isRetry: Bool) {
		print()
		print(flags.getString(name: "to")!.split(separator: ","))
		command.fail(statusCode: 1, errorMessage: "Todo")
	}
	
	override var isAsynchronous: Bool {
		return false
	}
	
}
