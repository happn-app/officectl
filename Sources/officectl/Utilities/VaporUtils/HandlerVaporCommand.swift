/*
 * HandlerVaporCommand.swift
 * officectl
 *
 * Created by François Lamboley on 07/08/2018.
 */

import Foundation

import ArgumentParser
import Vapor



/**
A Vapor command to run a custom handler… */
struct HandlerVaporCommand : Vapor.Command {
	
	struct Signature: CommandSignature {
	}
	
	let help = "Internal command to launch a custom handler command. You should never see this."
	
	typealias Run = (CommandContext) async throws -> Void
	let run: Run
	
	init(run r: @escaping Run) {
		run = r
	}
	
	func run(using context: CommandContext, signature: HandlerVaporCommand.Signature) throws {
		let group = DispatchGroup()
		group.enter()
		Task{
			try await run(context)
			group.leave()
		}
		group.wait()
	}
	
}
