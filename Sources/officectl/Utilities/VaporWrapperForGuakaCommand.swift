/*
 * VaporWrapperForGuakaCommand.swift
 * officectl
 *
 * Created by François Lamboley on 07/08/2018.
 */

import Foundation

import Guaka
import Vapor



struct VaporWrapperForGuakaCommand : Vapor.Command {
	
	struct Signature: CommandSignature {
	}
	
	let help = "Internal command to launch a Guaka command. You should never see this."
	
	let guakaCommand: Guaka.Command
	let guakaFlags: Guaka.Flags
	let guakaArgs: [String]
	
	typealias Run = (Guaka.Flags, [String], CommandContext, Application) throws -> EventLoopFuture<Void>
	weak var app: Application! /* See parse_cli for discussion about this. */
	let run: Run
	
	init(guakaCommand cmd: Guaka.Command, guakaFlags flags: Guaka.Flags, guakaArgs args: [String], app a: Application, run r: @escaping Run) {
		guakaCommand = cmd
		guakaFlags = flags
		guakaArgs = args
		app = a
		run = r
	}
	
	func run(using context: CommandContext, signature: VaporWrapperForGuakaCommand.Signature) throws {
		do    {try run(guakaFlags, guakaArgs, context, app).wait()}
		catch {guakaCommand.fail(statusCode: (error as NSError).code, errorMessage: error.legibleLocalizedDescription)}
	}
	
}
