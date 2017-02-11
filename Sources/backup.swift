import Guaka
import Security
import Foundation


var allUsers: [User]?
var superuser: Superuser?


var backupCommand = Command(
	usage: "backup", configuration: configuration, run: execute
)


private func configuration(command: Command) {
	command.add(
		flags: [
			Flag(longName: "admin-app-id", type: String.self, description: "The app id from which the admin refresh token is coming from.", required: true, inheritable: true),
			Flag(longName: "admin-app-secret", type: String.self, description: "The app secret from which the admin refresh token is coming from.", required: true, inheritable: true),
			Flag(longName: "admin-refresh-token", type: String.self, description: "A refresh token which gives access to the admin API. Must have at least the \"https://www.googleapis.com/auth/admin.directory.group https://www.googleapis.com/auth/admin.directory.user.readonly\" scope.", required: true, inheritable: true),
			Flag(longName: "superuser-json-creds", type: String.self, description: "The path to the json credentials for the superuser.", required: true, inheritable: true)
		]
	)
	command.inheritablePreRun = inheritablePreRun
}

private func inheritablePreRun(flags: Flags, args: [String]) -> Bool {
	let adminAppId = flags.getString(name: "admin-app-id")!
	let adminAppSecret = flags.getString(name: "admin-app-secret")!
	let refreshToken = flags.getString(name: "admin-refresh-token")!
	let jsonCredsURL = URL(fileURLWithPath: flags.getString(name: "superuser-json-creds")!, isDirectory: false)
	
	var keys: CFArray?
	guard
		let superuserCreds = (try? JSONSerialization.jsonObject(with: Data(contentsOf: jsonCredsURL), options: [])) as? [String: String],
		let jsonCredsType = superuserCreds["type"], jsonCredsType == "service_account",
		let superuserPEMKey = superuserCreds["private_key"]?.data(using: .utf8), let superuserEmail = superuserCreds["client_email"],
		SecItemImport(superuserPEMKey as CFData, nil, nil, nil, [], nil, nil, &keys) == 0, let superuserKey = (keys as? [SecKey])?.first
	else {
		rootCommand.fail(statusCode: 1, errorMessage: "Cannot read superuser creds")
	}
	
	superuser = Superuser(email: superuserEmail, privateKey: superuserKey)
	
	/* ********* Retrieving list of users ********* */
	/* First let's get an access token from the refresh token */
	let accessToken: String
	do {
		print("Getting access token from refresh token")
		var request = URLRequest(url: URL(string: "https://accounts.google.com/o/oauth2/token")!)
		var components = URLComponents()
		components.queryItems = [
			URLQueryItem(name: "client_id", value: adminAppId),
			URLQueryItem(name: "client_secret", value: adminAppSecret),
			URLQueryItem(name: "refresh_token", value: refreshToken),
			URLQueryItem(name: "grant_type", value: "refresh_token")
		]
		request.httpBody = components.percentEncodedQuery?.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "+").inverted)?.data(using: .utf8)
		request.httpMethod = "POST"
		guard
			let (data, response) = try? URLSession.shared.synchronousDataTask(with: request),
			let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
			let nonOptionalData = data, let parsedJson = (try? JSONSerialization.jsonObject(with: nonOptionalData, options: [])) as? [String: Any],
			let token = parsedJson["access_token"] as? String
		else {
			rootCommand.fail(statusCode: 1, errorMessage: "Cannot get access token")
		}
		accessToken = token
	}
	
	/* Then let's get the users in the directory */
	do {
		print("Getting users in directory")
		var usersDictionaries = [[String: Any]]()
		for domain in ["happn.fr", "happnambassadeur.com"] {
			var request = URLRequest(url: URL(string: "https://www.googleapis.com/admin/directory/v1/users?domain=\(domain)")!)
			request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
			request.httpMethod = "GET"
			guard
				let (data, response) = try? URLSession.shared.synchronousDataTask(with: request),
				let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
				let nonOptionalData = data, let parsedJson = (try? JSONSerialization.jsonObject(with: nonOptionalData, options: [])) as? [String: Any],
				let users = parsedJson["users"] as? [[String: Any]]
			else {
				rootCommand.fail(statusCode: 1, errorMessage: "Cannot get the list of users")
			}
			usersDictionaries.append(contentsOf: users)
		}
		allUsers = usersDictionaries.flatMap { userDictionary in
			guard let id = userDictionary["id"] as? String, let email = userDictionary["primaryEmail"] as? String else {return nil}
			return User(id: id, email: email)
		}
	}
	
	return true
}

private func execute(flags: Flags, args: [String]) {
	print("backup called")
}
