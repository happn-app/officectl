/*
 * DirectoryGroup.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/09/24.
 */

import Foundation

import Email

import OfficeModel



public protocol DirectoryGroup {
	
	associatedtype IDType : Hashable
	associatedtype PersistentIDType : Hashable
	
	var groupID: IDType {get}
	var remotePersistentID: RemoteProperty<PersistentIDType> {get}
	
	var remoteIdentifyingEmail: RemoteProperty<Email?> {get}
	
	var remoteName: RemoteProperty<String> {get}
	var remoteDescription: RemoteProperty<String> {get}
	
}


extension DirectoryGroup {
	
	var persistentID: PersistentIDType? {remotePersistentID.wrappedValue}
	
	var identifyingEmail: Email?? {remoteIdentifyingEmail.wrappedValue}
	
	var name: String? {remoteName.wrappedValue}
	var description: String? {remoteDescription.wrappedValue}
	
}



/* Note: Very sadly, the following piece of code do not compile because the wrapper (underscored variable) visibility cannot be changed.
 
 ----
 @propertyWrapper
 struct Wrapper<T> {var wrappedValue: T}
 
 /* Protocols cannot contain wrapped variables. */
 protocol WrapProtocol {
 	var _wrapped: Bob<Int> {get}
 }
 
 struct Wrap : WrapProtocol {
 	@Bob var wrapped: Int /* <- This declares _wrapped w/ private visibility; we need internal. */
 }
 ----
 
 If this code did work, the DirectoryUser and DirectoryGroup protocols would have underscore-prefixed remote properties, instead of remote-prefixed ones, and things would be easier… */
