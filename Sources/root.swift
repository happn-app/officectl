import Guaka
import Security
import Foundation


var rootConfig: RootConfig!
let rootCommand = Command(
	usage: "ghapp", configuration: configuration, run: execute
)

private func configuration(command: Command) {
	command.add(
		flags: [
			Flag(longName: "admin-email", type: String.self, description: "The email of an admin user in the domain.", required: true, inheritable: true),
			Flag(longName: "superuser-json-creds", type: String.self, description: "The path to the json credentials for the superuser.", required: true, inheritable: true)
		]
	)
	command.inheritablePreRun = inheritablePreRun
}

private func inheritablePreRun(flags: Flags, args: [String]) -> Bool {
	var keys: CFArray?
	let jsonCredsURL = URL(fileURLWithPath: flags.getString(name: "superuser-json-creds")!, isDirectory: false)
	guard
		let superuserCreds = (try? JSONSerialization.jsonObject(with: Data(contentsOf: jsonCredsURL), options: [])) as? [String: String],
		let jsonCredsType = superuserCreds["type"], jsonCredsType == "service_account",
		let superuserPEMKey = superuserCreds["private_key"]?.data(using: .utf8), let superuserEmail = superuserCreds["client_email"],
		SecItemImport(superuserPEMKey as CFData, nil, nil, nil, [], nil, nil, &keys) == 0, let superuserKey = (keys as? [SecKey])?.first
	else {
		rootCommand.fail(statusCode: 1, errorMessage: "Cannot read superuser creds")
	}
	
	rootConfig = RootConfig(adminEmail: flags.getString(name: "admin-email")!, superuser: Superuser(email: superuserEmail, privateKey: superuserKey))
	return true
}

private func execute(flags: Flags, args: [String]) {
	rootCommand.fail(statusCode: 1, errorMessage: "Please choose a command verb")
}


/* ***** Config Object ***** */

struct RootConfig {
	
	let adminEmail: String
	let superuser: Superuser
	
}
