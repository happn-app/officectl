/*
 * EmailUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/08/26.
 */

import Foundation

import Email

import OfficeModel



public struct EmailUser : DirectoryUser {
	
	public typealias IDType = Email
	public typealias PersistentIDType = Email
	
	public var userID: Email
	public var remotePersistentID: RemoteProperty<Email> {return .set(userID)}
	
	public var remoteIdentifyingEmail: RemoteProperty<Email?> {return .set(userID)}
	public var remoteOtherEmails: RemoteProperty<[Email]> {return .unsupported}
	
	public var remoteFirstName: RemoteProperty<String?> {return .unsupported}
	public var remoteLastName:  RemoteProperty<String?> {return .unsupported}
	public var remoteNickname:  RemoteProperty<String?> {return .unsupported}
	
}
