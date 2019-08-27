/*
 * EmailUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 26/08/2019.
 */

import Foundation



public struct EmailUser : DirectoryUser {
	
	public typealias UserIdType = Email
	public typealias PersistentIdType = Email
	
	public var userId: Email
	public var persistentId: RemoteProperty<Email> {return .set(userId)}
	
	public var identifyingEmail: RemoteProperty<Email?> {return .set(userId)}
	public var otherEmails: RemoteProperty<[Email]> {return .unsupported}
	
	public var firstName: RemoteProperty<String?> {return .unsupported}
	public var lastName:  RemoteProperty<String?> {return .unsupported}
	public var nickname:  RemoteProperty<String?> {return .unsupported}
	
}
