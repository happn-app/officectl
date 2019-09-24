/*
 * DirectoryGroup.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/09/2019.
 */

import Foundation



public protocol DirectoryGroup {
	
	associatedtype IdType : Hashable
	associatedtype PersistentIdType : Hashable
	
	var groupId: IdType {get}
	var persistentId: RemoteProperty<PersistentIdType> {get}
	
	var identifyingEmail: RemoteProperty<Email?> {get}
	
	var name: RemoteProperty<String> {get}
	var description: RemoteProperty<String> {get}
	
}
