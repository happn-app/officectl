import Guaka

var rootCommand = Command(
	usage: "ghapp", configuration: configuration, run: execute
)


private func configuration(command: Command) {
	command.add(
		flags: [
		]
	)
}

private func execute(flags: Flags, args: [String]) {
	rootCommand.fail(statusCode: 1, errorMessage: "Please choose a command verb.")
}
