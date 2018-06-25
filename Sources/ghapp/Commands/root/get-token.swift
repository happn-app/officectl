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

private func execute(command: Command, flags: Flags, args: [String]) {
	let op = HandlerOperation{ endOperation in
		rootConfig.googleConnector.unsafeConnect(scope: GoogleJWTConnector.ScopeType(userBehalf: rootConfig.adminEmail, scope: Set(flags.getString(name: "scopes")!.components(separatedBy: ","))), handler: { error in
			print(rootConfig.googleConnector.token ?? "Cannot retrieve the token")
			endOperation()
		})
	}
	op.start()
	op.waitUntilFinished()
}
