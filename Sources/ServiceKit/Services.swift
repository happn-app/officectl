/*
 * Services.swift
 * officectl
 *
 * Created by François Lamboley on 18/12/2019.
 */

import Foundation



public class Services {
	
	public enum Error : Swift.Error {
		
		case noFactory(for: Any.Type)
		
	}
	
	public init() {
	}
	
	public func make<T>(_ serviceType: T.Type = T.self) throws -> T {
		guard let factory = factories[ObjectIdentifier(serviceType)] as! (() -> T)? else {
			throw Error.noFactory(for: serviceType)
		}
		return factory()
	}
	
	private var factories = [ObjectIdentifier: Any]()
	
}
