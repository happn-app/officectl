import Guaka

var backupCommand = Command(
	usage: "backup", configuration: configuration, run: execute
)


private func configuration(command: Command) {
	command.add(
		flags: [
		]
	)
}

private func execute(flags: Flags, args: [String]) {
	print("backup called")
}
