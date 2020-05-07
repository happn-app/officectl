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



/* *** IMPORTANT: When adding a new property that set something in the storage,
 * do remember to access it in app.swift! */



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
		if let existing = storage[SemiSingletonStoreKey.self] {
			return existing
		} else {
			let new = SemiSingletonStore(forceClassInKeys: true)
			storage[SemiSingletonStoreKey.self] = new
			return new
		}
	}
	
	private struct SemiSingletonStoreKey: StorageKey {
		typealias Value = SemiSingletonStore
	}
	
}


extension Application {
	
	/* Note: Once this is accessed, officectlConfig won’t clear the cached
	 *       services provider. */
	var officeKitServiceProvider: OfficeKitServiceProvider {
		if let existing = storage[OfficeKitServiceProviderKey.self] {
			return existing
		} else {
			let new = OfficeKitServiceProvider(config: self.officeKitConfig)
			storage[OfficeKitServiceProviderKey.self] = new
			return new
		}
	}
	
	private struct OfficeKitServiceProviderKey: StorageKey {
		typealias Value = OfficeKitServiceProvider
	}
	
}


extension Application {
	
	var services: Services {
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
		if let existing = storage[AuditLoggerKey.self] {
			return existing
		} else {
			/* TODO: Let’s not crash if cannot create audit logger 😅 */
			let new = try! AuditLogger(path: officectlConfig.auditLogsURL?.path)
			storage[AuditLoggerKey.self] = new
			return new
		}
	}
	
	private struct AuditLoggerKey: StorageKey {
		typealias Value = AuditLogger
	}
	
}


extension Application {
	
	var officectlStorage: OfficectlStorage {
		if let existing = storage[OfficectlStorageKey.self] {
			return existing
		} else {
			let new = OfficectlStorage()
			storage[OfficectlStorageKey.self] = new
			return new
		}
	}
	
	private struct OfficectlStorageKey: StorageKey {
		typealias Value = OfficectlStorage
	}
	
}
