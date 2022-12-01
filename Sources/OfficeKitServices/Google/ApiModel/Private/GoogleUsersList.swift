/*
 * GoogleUsersList.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/12/01.
 */

import Foundation



public struct GoogleUsersList : Sendable, Codable {
	
	public enum Kind: String, Sendable, Codable {
		
		case user = "admin#directory#users"
		
	}
	
	public var kind: Kind
	public var etag: String
	
	public var users: [GoogleUser]?
	public var nextPageToken: String?
	
}
