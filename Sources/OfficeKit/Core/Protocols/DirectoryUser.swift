/*
 * DirectoryUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 01/07/2019.
 */

import Foundation



public protocol DirectoryUser {
	
	associatedtype IdType : Hashable/* & FallibleStringInitable */
	
	var id: IdType {get}
	
	var emails: RemoteProperty<[Email]> {get}
	
	var firstName: RemoteProperty<String?> {get}
	var lastName: RemoteProperty<String?> {get}
	var nickname: RemoteProperty<String?> {get}
	
}


public enum DirectoryUserProperty : Hashable {
	
	case email
	
	case firstName
	case lastName
	case nickname
	
	case custom(String)
	
}
