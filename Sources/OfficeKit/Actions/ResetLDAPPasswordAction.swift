/*
 * ResetLDAPPasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/11/2018.
 */

import Foundation

import SemiSingleton
import Vapor



public class ResetLDAPPasswordAction : SemiSingleton {
	
	public typealias SemiSingletonKey = HappnUser
	public typealias SemiSingletonAdditionalInitInfo = Void
	
	public required init(key u: HappnUser, additionalInfo: Void, store: SemiSingletonStore) {
	}
	
}
