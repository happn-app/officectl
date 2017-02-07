/*
 * User.swift
 * ghapp
 *
 * Created by François Lamboley on 2/6/17.
 *
 */

import Foundation



struct User : CustomStringConvertible {
	
	let id: String
	let email: String
	
	init(id theId: String, email theEmail: String) {
		id = theId
		email = theEmail
	}
	
	public var description: String {
		return "\(id):\(email)"
	}
	
	private var _accessToken: String? = nil
	private var _accessTokenScopes: Set<String>? = nil
	private var _accessTokenExpirationDate: Date? = nil
	mutating func accessToken(forScopes scopes: [String], withSuperuserEmail superuserEmail: String, superuserKey: SecKey) throws -> String {
		if let accessToken = _accessToken, let expirationDate = _accessTokenExpirationDate, expirationDate.timeIntervalSinceNow > 5*60, Set(scopes) == _accessTokenScopes {return accessToken}
		
		let scopeURL = URL(string: "https://www.googleapis.com/oauth2/v4/token")!
		let jwtRequestHeader = ["alg": "RS256", "typ": "JWT"]
		let jwtRequestContent: [String: Any] = [
			"iss": superuserEmail,
			"scope": scopes.joined(separator: " "), "aud": scopeURL.absoluteString,
			"iat": Int(Date(timeIntervalSinceNow: -3).timeIntervalSince1970), "exp": Int(Date(timeIntervalSinceNow: 30).timeIntervalSince1970),
			"sub": email
		]
		let jwtRequestHeaderBase64  = (try! JSONSerialization.data(withJSONObject: jwtRequestHeader, options: [])).base64EncodedString()
		let jwtRequestContentBase64 = (try! JSONSerialization.data(withJSONObject: jwtRequestContent, options: [])).base64EncodedString()
		let jwtRequestSignedString = jwtRequestHeaderBase64 + "." + jwtRequestContentBase64
		guard
			let jwtRequestSignedData = jwtRequestSignedString.data(using: .utf8),
			let superuserSigner = SecSignTransformCreate(superuserKey, nil),
			SecTransformSetAttribute(superuserSigner, kSecDigestTypeAttribute, kSecDigestSHA2, nil),
			SecTransformSetAttribute(superuserSigner, kSecDigestLengthAttribute, NSNumber(value: 256), nil),
			SecTransformSetAttribute(superuserSigner, kSecTransformInputAttributeName, jwtRequestSignedData as CFData, nil),
			let jwtRequestSignature = SecTransformExecute(superuserSigner, nil) as? Data
		else {
			print("*** Warning: Skipping user with id \(id), email \(email) because creating signature for JWT request to get access token failed")
			throw NSError(domain: "JWT", code: 1, userInfo: [NSLocalizedDescriptionKey: "Creating signature for JWT request to get access token failed."])
		}
		let jwtRequest = jwtRequestSignedString + "." + jwtRequestSignature.base64EncodedString()
		
		var allowedCharacters = CharacterSet.urlQueryAllowed
		allowedCharacters.remove(charactersIn: "+")
		
		var request = URLRequest(url: scopeURL)
		var components = URLComponents()
		components.queryItems = [
			URLQueryItem(name: "grant_type", value: "urn:ietf:params:oauth:grant-type:jwt-bearer"),
			URLQueryItem(name: "assertion", value: jwtRequest)
		]
		request.httpBody = components.query?.addingPercentEncoding(withAllowedCharacters: allowedCharacters)?.data(using: .utf8)
		request.httpMethod = "POST"
		guard
			let (data, response) = try? URLSession.shared.synchronousDataTask(with: request),
			let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
			let nonOptionalData = data, let parsedJson = (try? JSONSerialization.jsonObject(with: nonOptionalData, options: [])) as? [String: Any],
			let token = parsedJson["access_token"] as? String, let expireDelay = parsedJson["expires_in"] as? Int
		else {
			throw NSError(domain: "JWT", code: 1, userInfo: [NSLocalizedDescriptionKey: "Creating signature for JWT request to get access token failed."])
		}
		
		_accessToken = token
		_accessTokenScopes = Set(scopes)
		_accessTokenExpirationDate = Date(timeIntervalSinceNow: TimeInterval(expireDelay))
		return token
	}
	
}
