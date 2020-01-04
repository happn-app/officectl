/*
 * ServicesUtils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 03/01/2020.
 */

import Foundation

import NIO
import SemiSingleton
import ServiceKit



extension Services {
	
	func eventLoop() throws -> EventLoop {
		return try self.make()
	}
	
	func semiSingletonStore() throws -> SemiSingletonStore {
		return try self.make()
	}
	
	func semiSingleton<O : SemiSingleton>(forKey k: O.SemiSingletonKey) throws -> O where O.SemiSingletonAdditionalInitInfo == Void {
		return try semiSingletonStore().semiSingleton(forKey: k)
	}
	
	func semiSingleton<O : SemiSingletonWithFallibleInit>(forKey k: O.SemiSingletonKey) throws -> O where O.SemiSingletonAdditionalInitInfo == Void {
		return try semiSingletonStore().semiSingleton(forKey: k)
	}
	
}
