/*
 * GroupOfUsers.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/21.
 */

import Foundation

import Email



public protocol GroupOfUsers : Sendable {
	
	associatedtype IDType : Hashable & Sendable
	associatedtype PersistentIDType : Hashable & Sendable
	
	/** Optional because we cannot know the id of locally created group of users. */
	var groupID: IDType? {get}
	var persistentID: PersistentIDType? {get}
	
	var identifyingEmails: [Email]? {get}
	var otherEmails: [Email]? {get}
	
	var name: String? {get}
	var description: String? {get}
	
}
