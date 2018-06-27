/*
 * devtest_curtest.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

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
}
