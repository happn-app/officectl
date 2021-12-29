/*
 * AnyOfficeKitServiceConfig.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/06/28.
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
	var isHelperService: Bool {get}
	
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
	
	var isHelperService: Bool {
		return originalConfig.isHelperService
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
	
	public init(providerId pId: String, serviceId id: String, serviceName name: String, mergePriority p: Int?, keyedConfig: GenericStorage, pathsRelativeTo baseURL: URL?) throws {
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
	
	public var isHelperService: Bool {
		return box.isHelperService
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
	
	public func erase() -> AnyOfficeKitServiceConfig {
		if let erased = self as? AnyOfficeKitServiceConfig {
			return erased
		}
		
		return AnyOfficeKitServiceConfig(self)
	}
	
	public func unbox<ConfigType : OfficeKitServiceConfig>() -> ConfigType? {
		guard let anyConfig = self as? AnyOfficeKitServiceConfig else {
			/* Nothing to unbox, just return self */
			return self as? ConfigType
		}
		
		return (anyConfig.box as? ConcreteOfficeKitServiceConfigBox<ConfigType>)?.originalConfig ?? (anyConfig.box as? ConcreteOfficeKitServiceConfigBox<AnyOfficeKitServiceConfig>)?.originalConfig.unbox()
	}
	
}
