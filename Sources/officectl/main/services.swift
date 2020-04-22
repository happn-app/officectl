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
		return locks.lock(for: StorageLock.self).withLock{
			if let existing = storage[SemiSingletonStoreKey.self] {
				return existing
			} else {
				let new = SemiSingletonStore(forceClassInKeys: true)
				storage[SemiSingletonStoreKey.self] = new
				return new
			}
		}
	}
	
	private struct SemiSingletonStoreKey: StorageKey {
		typealias Value = SemiSingletonStore
	}
	
}


extension Application {
	
	var officeKitServiceProvider: OfficeKitServiceProvider {
		return locks.lock(for: StorageLock.self).withLock{
			if let existing = storage[OfficeKitServiceProviderKey.self] {
				return existing
			} else {
				let new = OfficeKitServiceProvider(config: self.officeKitConfig)
				storage[OfficeKitServiceProviderKey.self] = new
				return new
			}
		}
	}
	
	private struct OfficeKitServiceProviderKey: StorageKey {
		typealias Value = OfficeKitServiceProvider
	}
	
}


extension Application {
	
	var services: Services {
		return locks.lock(for: StorageLock.self).withLock{
			if let existing = storage[ServicesKey.self] {
				return existing
			} else {
				let new = Services()
				let eventLoop = self.eventLoopGroup.next()
				new.register{ eventLoop } /* We always want to return the same event loop */
				new.register{ self.semiSingletonStore }
				storage[ServicesKey.self] = new
				return new
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
		return locks.lock(for: StorageLock.self).withLock{
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
	
	private struct AuditLoggerKey: StorageKey {
		typealias Value = AuditLogger
	}
	
}


/** Use this lock to access or modify the storage in the app. IMHO Vapor should
not allow users to modify the storage outside of a lock; see https://discordapp.com/channels/431917998102675485/519613337638797315/702530003396591756
about this. */
struct StorageLock : LockKey {
}
