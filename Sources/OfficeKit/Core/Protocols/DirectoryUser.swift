/*
 * DirectoryUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 01/07/2019.
 */

import Foundation



public protocol DirectoryUser : Hashable {
	
	associatedtype IdType : Hashable/* & FallibleStringInitable */
	
	var id: IdType {get}
	
	var emails: RemoteProperty<[Email]> {get}
	
	var firstName: RemoteProperty<String?> {get}
	var lastName: RemoteProperty<String?> {get}
	var nickname: RemoteProperty<String?> {get}
	
}


extension DirectoryUser {
	
	public static func ==(_ user1: Self, _ user2: Self) -> Bool {
		return user1.id == user2.id
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
	
}


public enum DirectoryUserProperty : Hashable {
	
	case email
	
	case firstName
	case lastName
	case nickname
	
	case custom(String)
	
}
