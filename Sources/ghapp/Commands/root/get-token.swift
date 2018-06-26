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
		rootConfig.googleConnector.connect(scope: GoogleJWTConnector.ScopeType(userBehalf: rootConfig.adminEmail, scope: Set(flags.getString(name: "scopes")!.components(separatedBy: ","))), handler: { error in
			print(rootConfig.googleConnector.token ?? "Cannot retrieve Gogol token")
			
			let gitHubConnector = GitHubJWTConnector(appId: "14017", installationId: "220844", privateKeyURL: URL(fileURLWithPath: "/Users/frizlab/Downloads/officectl.2018-06-25.private-key.pem", isDirectory: false))!
			gitHubConnector.connect(scope: (), handler: { error in
				print(gitHubConnector.token ?? "Cannot retrieve GitHub token")
				endOperation()
			})
		})
	}
	op.start()
	repeat {
		RunLoop.current.run(mode: .defaultRunLoopMode, before: Date(timeIntervalSinceNow: 0.1))
	} while !op.isFinished
}
