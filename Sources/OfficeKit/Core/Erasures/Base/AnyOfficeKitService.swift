/*
 * AnyOfficeKitService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/09/24.
 */

import Foundation



private protocol OfficeKitServiceBox {
	
	/* *** Hashable *** */
	
	/* Needed only for the hashable erasure. NOT for other erasure stuff. */
	func unbox<T : OfficeKitService>() -> T?
	
	func hash(into hasher: inout Hasher)
	func isEqual(_ other: OfficeKitServiceBox) -> Bool
	
	/* *** OfficeKitService *** */
	
	var config: AnyOfficeKitServiceConfig {get}
	var globalConfig: GlobalConfig {get}
	
}

private struct ConcreteOfficeKitBox<Base : OfficeKitService> : OfficeKitServiceBox {
	
	let originalService: Base
	
	func unbox<T>() -> T? where T : OfficeKitService {
		return originalService as? T
	}
	
	func hash(into hasher: inout Hasher) {
		originalService.hash(into: &hasher)
	}
	
	func isEqual(_ other: OfficeKitServiceBox) -> Bool {
		guard let otherAsBase: Base = other.unbox() else {return false}
		return otherAsBase == originalService
	}
	
	var config: AnyOfficeKitServiceConfig {
		return originalService.config.erase()
	}
	
	var globalConfig: GlobalConfig {
		return originalService.globalConfig
	}
	
}

public class AnyOfficeKitService : OfficeKitService {
	
	public static var providerID: String {
		assertionFailure("Please do not use providerID on AnyOfficeKitService. This is an erasure for a concrete OfficeKitService type.")
		return "__OfficeKitInternal_OfficeKitServiceConfig_Erasure__"
	}
	
	public typealias ConfigType = AnyOfficeKitServiceConfig
	public typealias UserType = AnyDirectoryUser
	
	/* See AnyDirectoryAuthenticatorService for info about the init for this erasure and subclasses */
	
	init<T : OfficeKitService>(s object: T) {
		box = ConcreteOfficeKitBox(originalService: object)
	}
	
	public required init(config c: AnyOfficeKitServiceConfig, globalConfig gc: GlobalConfig) {
		fatalError("init(config:globalConfig:) unavailable for a directory service erasure")
	}
	
	public func hash(into hasher: inout Hasher) {
		box.hash(into: &hasher)
	}
	
	public static func ==(_ lhs: AnyOfficeKitService, _ rhs: AnyOfficeKitService) -> Bool {
		return lhs.box.isEqual(rhs.box)
	}
	
	public var config: AnyOfficeKitServiceConfig {
		return box.config
	}
	
	public var globalConfig: GlobalConfig {
		return box.globalConfig
	}
	
	fileprivate let box: OfficeKitServiceBox
	
}

extension OfficeKitService {
	
	public func erase() -> AnyOfficeKitService {
		if let erased = self as? AnyOfficeKitService {
			return erased
		}
		
		return AnyOfficeKitService(s: self)
	}
	
	public func unbox<DirectoryType : OfficeKitService>() -> DirectoryType? {
		guard let anyService = self as? AnyOfficeKitService, !(DirectoryType.self is AnyOfficeKitService.Type) else {
			/* Nothing to unbox, just return self */
			return self as? DirectoryType
		}
		
		return (anyService.box as? ConcreteOfficeKitBox<DirectoryType>)?.originalService ?? (anyService.box as? ConcreteOfficeKitBox<AnyOfficeKitService>)?.originalService.unbox()
	}
	
}
