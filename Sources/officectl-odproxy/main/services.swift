/*
 * services.swift
 * officectl-odproxy
 *
 * Created by François Lamboley on 2020/01/06.
 */

import Foundation

import OfficeKit
import SemiSingleton
import ServiceKit
import Vapor



extension Application {
	
	var services: Services {
		/* I’m not sure accessing storage outside of the queue is thread-safe… */
		if let existing = storage[ServicesKey.self] {
			return existing
		} else {
			return Application.depRegisteringQueue.sync{
				if let existing = storage[ServicesKey.self] {
					return existing
				} else {
					var new = Services()
					let queue = OperationQueue()
					new.register{ queue } /* We always want to return the same queue */
					storage[ServicesKey.self] = new
					return new
				}
			}
		}
	}
	
	private struct ServicesKey: StorageKey {
		typealias Value = Services
	}
	
}


extension Request {
	
	var services: Services {
		let ret = Services(duplicating: application.services)
		return ret
	}
	
}



private extension Application {
	
	private static var depRegisteringQueue: DispatchQueue {
		return DispatchQueue(label: "Dependency registration queue")
	}
	
}
