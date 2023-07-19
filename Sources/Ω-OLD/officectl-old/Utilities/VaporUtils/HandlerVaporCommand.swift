/*
 * HandlerVaporCommand.swift
 * officectl
 *
 * Created by François Lamboley on 2018/08/07.
 */

import Foundation

import ArgumentParser
import Vapor



/**
 A Vapor command to run a custom handler… */
class HandlerVaporCommand : Vapor.Command {
	
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
			do    {try await run(context)}
			catch {err = error}
			group.leave()
		}
		group.wait()
		if let err = err {throw err}
	}
	
	private var err: Error?
	
}
