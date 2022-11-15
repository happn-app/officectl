/*
 * HappnUser.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/15.
 */

import Foundation

import Email
import OfficeKit2



public struct HappnUser : User {
	
	public typealias IDType = Email
	public typealias PersistentIDType = Never
	
	public var id: Email
	public var persistentID: Never? {nil}
	
	public var firstName: String? {nil}
	public var lastName: String?  {nil}
	public var nickname: String?  {nil}
	
	public var emails: [Email]? {[id]} /* TODO: Domains map? */
	
	public var password: String? {nil}
	
	public func valueForNonStandardProperty(_ property: String) -> Any? {
		return nil
	}
	
}
