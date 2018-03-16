import Guaka
import Foundation


let devtestCurtestCommand = Command(
	usage: "curtest", configuration: configuration, run: execute
)

private func configuration(command: Command) {
	command.add(
		flags: [
		]
	)
}

private func execute(command: Command, flags: Flags, args: [String]) {
	print("hello!")
}
