/*
 * User.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/12.
 */

import Foundation

import Email
import ModelCore



public protocol DirectoryUser<IDType> : Sendable {
	
	associatedtype IDType : Hashable & Sendable
	associatedtype PersistentIDType : Hashable & Sendable
	
	var userID: IDType {get}
	var remotePersistentID: RemoteProperty<PersistentIDType> {get}
	
	var remoteIdentifyingEmail: RemoteProperty<Email?> {get}
	var remoteOtherEmails: RemoteProperty<[Email]> {get}
	
//	var remoteFullName: RemoteProperty<String?> {get}
	var remoteFirstName: RemoteProperty<String?> {get}
	var remoteLastName: RemoteProperty<String?> {get}
	var remoteNickname: RemoteProperty<String?> {get}
	
}
