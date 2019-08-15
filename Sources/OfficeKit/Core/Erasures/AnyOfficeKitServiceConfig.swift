/*
 * AnyOfficeKitServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 28/06/2019.
 */

import Foundation

import GenericStorage



private protocol OfficeKitServiceConfigBox {
	
	/* *** Hashable *** */
	
	func unbox<T : OfficeKitServiceConfig>() -> T?
	
	func hash(into hasher: inout Hasher)
	func isEqual(_ other: OfficeKitServiceConfigBox) -> Bool
	
	/* *** OfficeKitServiceConfig *** */
	
	var providerId: String {get}
	var serviceId: String {get}
	var serviceName: String {get}
	
	var mergePriority: Int? {get}
	
}

private struct ConcreteOfficeKitServiceConfigBox<Base : OfficeKitServiceConfig> : OfficeKitServiceConfigBox {
	
	let originalConfig: Base
	
	func unbox<T : Hashable>() -> T? {
		return originalConfig as? T
	}
	
	func hash(into hasher: inout Hasher) {
		originalConfig.hash(into: &hasher)
	}
	
	func isEqual(_ other: OfficeKitServiceConfigBox) -> Bool {
		guard let otherAsBase: Base = other.unbox() else {return false}
		return otherAsBase == originalConfig
	}
	
	var providerId: String {
		return originalConfig.providerId
	}
	
	var serviceId: String {
		return originalConfig.serviceId
	}
	
	var serviceName: String {
		return originalConfig.serviceName
	}
	
	var mergePriority: Int? {
		return originalConfig.mergePriority
	}
	
	init(originalConfig v: Base) {
		originalConfig = v
	}
	
}

public struct AnyOfficeKitServiceConfig : OfficeKitServiceConfig {
	
	init<T : OfficeKitServiceConfig>(_ object: T) {
		box = ConcreteOfficeKitServiceConfigBox(originalConfig: object)
	}
	
	public init(globalConfig: GlobalConfig, providerId pId: String, serviceId id: String, serviceName name: String, genericConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
		throw InternalError(message: "AnyOfficeKitServiceConfig cannot be instantiated with a generic config…")
	}
	
	public func hash(into hasher: inout Hasher) {
		box.hash(into: &hasher)
	}
	
	public static func ==(_ lhs: AnyOfficeKitServiceConfig, _ rhs: AnyOfficeKitServiceConfig) -> Bool {
		return lhs.box.isEqual(rhs.box)
	}
	
	public var providerId: String {
		return box.providerId
	}
	
	public var serviceId: String {
		return box.serviceId
	}
	
	public var serviceName: String {
		return box.serviceName
	}
	
	public var mergePriority: Int? {
		return box.mergePriority
	}
	
	fileprivate let box: OfficeKitServiceConfigBox
	
}


extension OfficeKitServiceConfig {
	
	public func erased() -> AnyOfficeKitServiceConfig {
		if let erased = self as? AnyOfficeKitServiceConfig {
			return erased
		}
		
		return AnyOfficeKitServiceConfig(self)
	}
	
	public func unboxed<ConfigType : OfficeKitServiceConfig>() -> ConfigType? {
		guard let anyConfig = self as? AnyOfficeKitServiceConfig else {
			/* Nothing to unbox, just return self */
			return self as? ConfigType
		}
		
		return (anyConfig.box as? ConcreteOfficeKitServiceConfigBox<ConfigType>)?.originalConfig ?? (anyConfig.box as? ConcreteOfficeKitServiceConfigBox<AnyOfficeKitServiceConfig>)?.originalConfig.unboxed()
	}
	
}
