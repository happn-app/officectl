/*
 * ResetGooglePasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 18/09/2018.
 */

import Foundation

import SemiSingleton
import Vapor



public class ResetGooglePasswordAction : SemiSingleton {
	
	public typealias SemiSingletonKey = User
	public typealias SemiSingletonAdditionalInitInfo = Void

	public required init(key u: User, additionalInfo: Void, store: SemiSingletonStore) {
	}
	
}
