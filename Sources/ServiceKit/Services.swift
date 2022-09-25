/*
 * Services.swift
 * officectl
 *
 * Created by François Lamboley on 2019/12/18.
 */

import Foundation



public struct Services : Sendable {
	
	public enum Error : Swift.Error {
		
		case factoryAlreadyRegistered(for: Any.Type)
		case noFactory(for: Any.Type)
		
	}
	
	public init() {
	}
	
	public init(duplicating services: Services) {
		factories = services.factories
	}
	
	public mutating func register<T>(factory: @Sendable @escaping () -> T) {
		try! register(factory: factory, allowOverride: true)
	}
	
	public mutating func register<T>(factory: @Sendable @escaping () -> T, allowOverride: Bool) throws {
		guard allowOverride || factories[ObjectIdentifier(T.self)] == nil else {
			throw Error.factoryAlreadyRegistered(for: T.self)
		}
		factories[ObjectIdentifier(T.self)] = factory
	}
	
	public func make<T>(_ serviceType: T.Type = T.self) throws -> T {
		guard let factory = factories[ObjectIdentifier(serviceType)] as! (() -> T)? else {
			throw Error.noFactory(for: serviceType)
		}
		return factory()
	}
	
	private var factories = [ObjectIdentifier: any Sendable]()
	
}
