/*
 * Superuser.swift
 * ghapp
 *
 * Created by François Lamboley on 2/11/17.
 *
 */

import Foundation



struct Superuser {
	
	let email: String
	let privateKey: SecKey
	
	func getAccessToken(forScopes scopes: Set<String>, onBehalfOfUserWithEmail subemail: String?) throws -> (String, Date) {
		let authURL = URL(string: "https://www.googleapis.com/oauth2/v4/token")!
		let jwtRequestHeader = ["alg": "RS256", "typ": "JWT"]
		var jwtRequestContent: [String: Any] = [
			"iss": email,
			"scope": scopes.joined(separator: " "), "aud": authURL.absoluteString,
			"iat": Int(Date(timeIntervalSinceNow: -3).timeIntervalSince1970), "exp": Int(Date(timeIntervalSinceNow: 30).timeIntervalSince1970)
		]
		if let subemail = subemail {jwtRequestContent["sub"] = subemail}
		let jwtRequestHeaderBase64  = (try! JSONSerialization.data(withJSONObject: jwtRequestHeader, options: [])).base64EncodedString()
		let jwtRequestContentBase64 = (try! JSONSerialization.data(withJSONObject: jwtRequestContent, options: [])).base64EncodedString()
		let jwtRequestSignedString = jwtRequestHeaderBase64 + "." + jwtRequestContentBase64
		guard
			let jwtRequestSignedData = jwtRequestSignedString.data(using: .utf8),
			let superuserSigner = SecSignTransformCreate(privateKey, nil),
			SecTransformSetAttribute(superuserSigner, kSecDigestTypeAttribute, kSecDigestSHA2, nil),
			SecTransformSetAttribute(superuserSigner, kSecDigestLengthAttribute, NSNumber(value: 256), nil),
			SecTransformSetAttribute(superuserSigner, kSecTransformInputAttributeName, jwtRequestSignedData as CFData, nil),
			let jwtRequestSignature = SecTransformExecute(superuserSigner, nil) as? Data
		else {
			throw NSError(domain: "JWT", code: 1, userInfo: [NSLocalizedDescriptionKey: "Creating signature for JWT request to get access token failed."])
		}
		let jwtRequest = jwtRequestSignedString + "." + jwtRequestSignature.base64EncodedString()
		
		var request = URLRequest(url: authURL)
		var components = URLComponents()
		components.queryItems = [
			URLQueryItem(name: "grant_type", value: "urn:ietf:params:oauth:grant-type:jwt-bearer"),
			URLQueryItem(name: "assertion", value: jwtRequest)
		]
		request.httpBody = components.percentEncodedQuery?.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "+").inverted)?.data(using: .utf8)
		request.httpMethod = "POST"
		guard
			let (data, response) = try? URLSession.shared.synchronousDataTask(with: request),
			let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
			let nonOptionalData = data, let parsedJson = (try? JSONSerialization.jsonObject(with: nonOptionalData, options: [])) as? [String: Any],
			let token = parsedJson["access_token"] as? String, let expireDelay = parsedJson["expires_in"] as? Int
		else {
			throw NSError(domain: "JWT", code: 1, userInfo: [NSLocalizedDescriptionKey: "Creating signature for JWT request to get access token failed."])
		}
		
		let expirationDate = Date(timeIntervalSinceNow: TimeInterval(expireDelay))
		return (token, expirationDate)
	}
	
	func retrieveUsers(using adminEmail: String, with domains: Set<String>, contrainedTo emails: Set<String>? = nil, verbose: Bool = false) throws -> [User] {
		/* First let's get an access token from the refresh token */
		if verbose {print("Getting access token from superuser creds")}
		let (accessToken, _) = try getAccessToken(forScopes: ["https://www.googleapis.com/auth/admin.directory.group", "https://www.googleapis.com/auth/admin.directory.user.readonly"], onBehalfOfUserWithEmail: adminEmail)
		
		/* Then let's get the users in the directory */
		if verbose {print("Getting users in directory")}
		var usersDictionaries = [[String: Any]]()
		for domain in domains {
			var nextPageToken: String?
			repeat {
				var request = URLRequest(url: URL(string: "https://www.googleapis.com/admin/directory/v1/users?domain=\(domain)" + (nextPageToken.flatMap{ "&pageToken=\($0)" } ?? ""))!)
				request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
				request.httpMethod = "GET"
				guard
					let (data, response) = try? URLSession.shared.synchronousDataTask(with: request),
					let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
					let nonOptionalData = data, let parsedJson = (try? JSONSerialization.jsonObject(with: nonOptionalData, options: [])) as? [String: Any],
					let users = parsedJson["users"] as? [[String: Any]]
				else {
					throw NSError(domain: "Superuser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot get the list of users for domain \(domain)"])
				}
				usersDictionaries.append(contentsOf: users)
				nextPageToken = parsedJson["nextPageToken"] as? String
			} while (nextPageToken != nil)
		}
		return usersDictionaries.flatMap { userDictionary in
			guard let id = userDictionary["id"] as? String, let email = userDictionary["primaryEmail"] as? String else {return nil}
			if let emails = emails {guard emails.contains(email) else {return nil}}
			return User(id: id, email: email, givenName: (userDictionary["name"] as? [String: Any?])?["givenName"] as? String)
		}
	}
	
}
