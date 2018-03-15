import Guaka
import Foundation


let devtestCommand = Command(
	usage: "devtest", configuration: configuration, run: execute
)

private func configuration(command: Command) {
	command.add(
		flags: [
		]
	)
}

private func execute(command: Command, flags: Flags, args: [String]) {
	rootCommand.fail(statusCode: 1, errorMessage: "Please choose what to test...")
}
