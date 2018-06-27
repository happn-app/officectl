/*
 * User.swift
 * officectl
 *
 * Created by François Lamboley on 2/6/17.
 *
 */

import Foundation



class User : CustomStringConvertible, Hashable, Equatable {
	
	let id: String
	let email: String
	let givenName: String?
	
	init(id theId: String, email theEmail: String, givenName theGivenName: String? = nil) {
		id = theId
		email = theEmail
		givenName = theGivenName
	}
	
	init?(json userDictionary: [String: Any?]) {
		guard let theId = userDictionary["id"] as? String, let theEmail = userDictionary["primaryEmail"] as? String else {
			return nil
		}
		
		id = theId
		email = theEmail
		givenName = (userDictionary["name"] as? [String: Any?])?["givenName"] as? String
	}
	
	public var description: String {
		return "\(id):\(email)"
	}
	
	private var _accessToken: String? = nil
	private var _accessTokenScopes: Set<String>? = nil
	private var _accessTokenExpirationDate: Date? = nil
	func accessToken(forScopes scopes: Set<String>, withSuperuser superuser: Superuser, forceRegeneration: Bool = false) throws -> (String, Date) {
		if !forceRegeneration, let accessToken = _accessToken, let expirationDate = _accessTokenExpirationDate, expirationDate.timeIntervalSinceNow > 5*60, _accessTokenScopes?.isSuperset(of: scopes) ?? false {return (accessToken, expirationDate)}
		
		let (token, expirationDate) = try superuser.getAccessToken(forScopes: scopes, onBehalfOfUserWithEmail: email)
		_accessToken = token
		_accessTokenScopes = Set(scopes)
		_accessTokenExpirationDate = expirationDate
		return (token, expirationDate)
	}
	
	var hashValue: Int {
		return id.hashValue
	}
	
	static func ==(_ lhs: User, _ rhs: User) -> Bool {
		return lhs.id == rhs.id
	}
	
}
