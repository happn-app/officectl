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
	
	var officectlConfig: OfficectlConfig {
		get {storage[OfficectlConfigKey.self]!}
		set {storage[OfficectlConfigKey.self] = newValue}
	}
	
	var officeKitConfig: OfficeKitConfig {
		self.officectlConfig.officeKitConfig
	}
	
	private struct OfficectlConfigKey: StorageKey {
		typealias Value = OfficectlConfig
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
	
	var officeKitServiceProvider: OfficeKitServiceProvider {
		/* I’m not sure accessing storage outside of the queue is thread-safe… */
		if let existing = storage[OfficeKitServiceProviderKey.self] {
			return existing
		} else {
			return Application.depRegisteringQueue.sync{
				if let existing = storage[OfficeKitServiceProviderKey.self] {
					return existing
				} else {
					let new = OfficeKitServiceProvider(config: self.officeKitConfig)
					storage[OfficeKitServiceProviderKey.self] = new
					return new
				}
			}
		}
	}
	
	private struct OfficeKitServiceProviderKey: StorageKey {
		typealias Value = OfficeKitServiceProvider
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


extension Application {
	
	var auditLogger: AuditLogger {
		/* I’m not sure accessing storage outside of the queue is thread-safe… */
		if let existing = storage[AuditLoggerKey.self] {
			return existing
		} else {
			return Application.depRegisteringQueue.sync{
				if let existing = storage[AuditLoggerKey.self] {
					return existing
				} else {
					/* TODO: Let’s not crash if cannot create audit logger 😅 */
					let new = try! AuditLogger(path: officectlConfig.auditLogsURL?.path)
					storage[AuditLoggerKey.self] = new
					return new
				}
			}
		}
	}
	
	private struct AuditLoggerKey: StorageKey {
		typealias Value = AuditLogger
	}
	
}



private extension Application {
	
	private static var depRegisteringQueue: DispatchQueue {
		return DispatchQueue(label: "Dependency registration queue")
	}
	
}
