import Guaka
import Foundation


let gettokenCommand = Command(
	usage: "get-token", configuration: configuration, run: execute
)

private func configuration(command: Command) {
	command.add(
		flags: [
			Flag(longName: "scopes", type: String.self, description: "A comma-separated list of scopes.")
		]
	)
}

private func execute(flags: Flags, args: [String]) {
	guard let token = try? rootConfig.superuser.getAccessToken(forScopes: Set(flags.getString(name: "scopes")!.components(separatedBy: ",")), onBehalfOfUserWithEmail: rootConfig.adminEmail) else {
		gettokenCommand.fail(statusCode: 2, errorMessage: "Cannot get token")
	}
	print(token.0)
}
