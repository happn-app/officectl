/*
 * services.swift
 * officectl_odproxy
 *
 * Created by François Lamboley on 06/01/2020.
 */

import Foundation

import OfficeKit
import SemiSingleton
import ServiceKit
import Vapor



extension Application {
	
	public var globalConfig: GlobalConfig {
		get {storage[GlobalConfigKey.self] ?? .init()}
		set {storage[GlobalConfigKey.self] = newValue}
	}
	
	private struct GlobalConfigKey: StorageKey {
		typealias Value = GlobalConfig
	}
	
}


extension Application {
		
	var semiSingletonStore: SemiSingletonStore {
		/* I’m not sure accessing storage outside of the queue is thread-safe… */
		if let existing = storage[SemiSingletonStoreKey.self] {
			return existing
		} else {
			return Application.depRegisteringQueue.sync{
				if let existing = storage[SemiSingletonStoreKey.self] {
					return existing
				} else {
					let new = SemiSingletonStore(forceClassInKeys: true)
					storage[SemiSingletonStoreKey.self] = new
					return new
				}
			}
		}
	}
	
	private struct SemiSingletonStoreKey: StorageKey {
		typealias Value = SemiSingletonStore
	}
	
}


extension Application {
	
	var openDirectoryService: OpenDirectoryService {
		/* I’m not sure accessing storage outside of the queue is thread-safe… */
		if let existing = storage[OpenDirectoryServiceKey.self] {
			return existing
		} else {
			return Application.depRegisteringQueue.sync{
				if let existing = storage[OpenDirectoryServiceKey.self] {
					return existing
				} else {
					let new = OpenDirectoryService(config: openDirectoryServiceConfig, globalConfig: globalConfig)
					storage[OpenDirectoryServiceKey.self] = new
					return new
				}
			}
		}
	}
	
	public var openDirectoryServiceConfig: OpenDirectoryServiceConfig {
		get {storage[OpenDirectoryServiceConfigKey.self]!}
		set {storage[OpenDirectoryServiceConfigKey.self] = newValue}
	}
	
	private struct OpenDirectoryServiceKey: StorageKey {
		typealias Value = OpenDirectoryService
	}
	
	private struct OpenDirectoryServiceConfigKey: StorageKey {
		typealias Value = OpenDirectoryServiceConfig
	}
	
}


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
					let new = Services()
					new.register{ self.eventLoopGroup.next() }
					new.register{ self.semiSingletonStore }
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
		ret.register{ self.eventLoop }
		return ret
	}
	
}



private extension Application {
	
	private static var depRegisteringQueue: DispatchQueue {
		return DispatchQueue(label: "Dependency registration queue")
	}
	
}
