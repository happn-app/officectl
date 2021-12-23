/*
 * Connector+Utils.swift
 * officectl
 *
 * Created by François Lamboley on 23/12/2021.
 */

import Foundation

import APIConnectionProtocols



extension Connector {
	
	/* That was easy… and not ugly at all! */
	nonisolated var isConnectedNonAsync: Bool {
		let isConnected = BoolWrapper()
		let group = DispatchGroup()
		group.enter()
		Task{
			isConnected.b = await (currentScope != nil)
			group.leave()
		}
		group.wait()
		return isConnected.b
	}
	
}

private class BoolWrapper {var b: Bool = false}
