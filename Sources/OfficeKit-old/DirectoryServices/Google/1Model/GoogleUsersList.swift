/*
 * GoogleUsersList.swift
 * officectl
 *
 * Created by François Lamboley on 2018/06/26.
 */

import Foundation



public struct GoogleUsersList : Codable {
	
	public enum Kind: String, Codable {
		
		case user = "admin#directory#users"
		
	}
	
	public var kind: Kind
	public var etag: String
	
	public var users: [GoogleUser]?
	public var nextPageToken: String?
	
}
