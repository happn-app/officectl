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
			Flag(longName: "admin-email", type: String.self, description: "The email of an admin user in the domain.", required: true, inheritable: true),
			Flag(longName: "superuser-json-creds", type: String.self, description: "The path to the json credentials for the superuser.", required: true, inheritable: true),
			Flag(longName: "emails-to-backup", type: String.self, description: "A comma-separated list of emails to backup. If an email is not in the directory, it is skipped. If not specified, all emails are backed up.", required: false, inheritable: true)
		]
	)
	command.inheritablePreRun = inheritablePreRun
}

private func inheritablePreRun(flags: Flags, args: [String]) -> Bool {
	let adminEmail = flags.getString(name: "admin-email")!
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
	
	let su = Superuser(email: superuserEmail, privateKey: superuserKey)
	superuser = su
	
	/* ********* Retrieving list of users ********* */
	/* First let's get an access token from the refresh token */
	let accessToken: String
	do {
		print("Getting access token from superuser creds")
		(accessToken, _) = try su.getAccessToken(forScopes: ["https://www.googleapis.com/auth/admin.directory.group", "https://www.googleapis.com/auth/admin.directory.user.readonly"], onBehalfOfUserWithEmail: adminEmail)
	} catch {
		rootCommand.fail(statusCode: 1, errorMessage: "Cannot get access token")
	}
	
	/* Then let's get the users in the directory */
	do {
		print("Getting users in directory")
		let emailsList = (flags.getString(name: "emails-to-backup")?.components(separatedBy: ",")).flatMap{ Set($0) }
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
			if let emailsList = emailsList {guard emailsList.contains(email) else {return nil}}
			return User(id: id, email: email)
		}
	}
	
	return true
}

private func execute(flags: Flags, args: [String]) {
	print("backup called")
}
