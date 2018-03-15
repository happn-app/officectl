import Guaka
import Foundation


let listusersCommand = Command(
	usage: "list-users", configuration: configuration, run: execute
)

private func configuration(command: Command) {
	command.add(
		flags: [
		]
	)
}

private func execute(command: Command, flags: Flags, args: [String]) {
	guard let users = try? rootConfig.superuser.retrieveUsers(using: rootConfig.adminEmail, with: ["happn.fr"], contrainedTo: nil, verbose: false) else {
		listusersCommand.fail(statusCode: 1, errorMessage: "cannot retrieve users")
	}
	
	for user in users {
		print(user.email + ",", terminator: "")
	}
	print()
}
