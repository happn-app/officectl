import Guaka

var rootCommand = Command(
	usage: "ghapp", configuration: configuration, run: execute
)


private func configuration(command: Command) {
	command.add(
		flags: [
			Flag(longName: "admin-refresh-token", type: String.self, description: "A refresh token which gives access to the admin API. Must have at least the \"https://www.googleapis.com/auth/admin.directory.group https://www.googleapis.com/auth/admin.directory.user.readonly\" scope."),
			Flag(longName: "superuser-json-creds", type: String.self, description: "The path to the json credentials for the superuser.")
		]
	)
}

private func execute(flags: Flags, args: [String]) {
	print("ghapp called")
}
