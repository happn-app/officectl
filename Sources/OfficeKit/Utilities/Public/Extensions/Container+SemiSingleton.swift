/*
 * Container+SemiSingleton.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/7/6.
 */

import Foundation

import SemiSingleton
import Vapor



//extension Container {
//
//	public func makeSemiSingleton<O : SemiSingleton>(forKey k: O.SemiSingletonKey, additionalInitInfo: O.SemiSingletonAdditionalInitInfo) throws -> O {
//		let store: SemiSingletonStore = try make()
//		return store.semiSingleton(forKey: k, additionalInitInfo: additionalInitInfo)
//	}
//
//	public func makeSemiSingleton<O : SemiSingleton>(forKey k: O.SemiSingletonKey) throws -> O where O.SemiSingletonAdditionalInitInfo == Void {
//		return try makeSemiSingleton(forKey: k, additionalInitInfo: ())
//	}
//
//	public func makeSemiSingleton<O : SemiSingletonWithFallibleInit>(forKey k: O.SemiSingletonKey, additionalInitInfo: O.SemiSingletonAdditionalInitInfo) throws -> O {
//		let store: SemiSingletonStore = try make()
//		return try store.semiSingleton(forKey: k, additionalInitInfo: additionalInitInfo)
//	}
//
//	public func makeSemiSingleton<O : SemiSingletonWithFallibleInit>(forKey k: O.SemiSingletonKey) throws -> O where O.SemiSingletonAdditionalInitInfo == Void {
//		return try makeSemiSingleton(forKey: k, additionalInitInfo: ())
//	}
//
//}
