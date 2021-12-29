/*
 * DirectoryGroup.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/09/24.
 */

import Foundation

import Email



public protocol DirectoryGroup {
	
	associatedtype IdType : Hashable
	associatedtype PersistentIdType : Hashable
	
	var groupId: IdType {get}
	var persistentId: RemoteProperty<PersistentIdType> {get}
	
	var identifyingEmail: RemoteProperty<Email?> {get}
	
	var name: RemoteProperty<String> {get}
	var description: RemoteProperty<String> {get}
	
}
