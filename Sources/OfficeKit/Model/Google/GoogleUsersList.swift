/*
 * GoogleUsersList.swift
 * officectl
 *
 * Created by François Lamboley on 26/06/2018.
 */

import Foundation



public struct GoogleUsersList : Codable {
	
	public enum Kind: String, Codable {
		
		case user = "admin#directory#users"
		
	}
	
	public var kind: Kind
	public var etag: String
	
	public var users: [GoogleUser]
	public var nextPageToken: String?
	
	#if os(Linux)
		/* We can get rid of this when Linux supports keyDecodingStrategy */
		private enum CodingKeys : String, CodingKey {
			case kind, etag
			case users, nextPageToken = "next_page_token"
		}
	#endif
	
}
