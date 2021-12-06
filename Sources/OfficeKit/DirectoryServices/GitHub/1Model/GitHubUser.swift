/*
 * GitHubUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 02/07/2019.
 */

import Foundation

import Email



public struct GitHubUser : DirectoryUser {
	
	public typealias IdType = String
	public typealias PersistentIdType = String
	
	public var userId: String
	public var persistentId: RemoteProperty<String>
	
	public var identifyingEmail: RemoteProperty<Email?>
	public var otherEmails: RemoteProperty<[Email]>
	
	public var firstName: RemoteProperty<String?>
	public var lastName: RemoteProperty<String?>
	public var nickname: RemoteProperty<String?>
	
}
