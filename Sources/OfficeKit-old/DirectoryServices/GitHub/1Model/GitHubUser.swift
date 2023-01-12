/*
 * GitHubUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/07/02.
 */

import Foundation

import Email

import OfficeModel



public struct GitHubUser : DirectoryUser {
	
	public typealias IDType = String
	public typealias PersistentIDType = String
	
	public var userID: String
	@RemoteProperty
	public var persistentID: String?
	public var remotePersistentID: RemoteProperty<String> {_persistentID}

	@RemoteProperty
	public var identifyingEmail: Email??
	public var remoteIdentifyingEmail: RemoteProperty<Email?>
	@RemoteProperty
	public var otherEmails: [Email]?
	public var remoteOtherEmails: RemoteProperty<[Email]>
	
	@RemoteProperty
	public var firstName: String??
	public var remoteFirstName: RemoteProperty<String?> {_firstName}
	@RemoteProperty
	public var lastName: String??
	public var remoteLastName: RemoteProperty<String?> {_lastName}
	@RemoteProperty
	public var nickname: String??
	public var remoteNickname: RemoteProperty<String?> {_nickname}
	
}
