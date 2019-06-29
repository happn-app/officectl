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
	
	let help = ["Internal command to launch a Guaka command. You should never see this."]
	
	let options = [CommandOption]()
	let arguments = [CommandArgument]()
	
	let guakaCommand: Guaka.Command
	let guakaFlags: Guaka.Flags
	let guakaArgs: [String]
	
	typealias Run = (Guaka.Flags, [String], CommandContext) throws -> Future<Void>
	let run: Run
	
	init(guakaCommand cmd: Guaka.Command, guakaFlags flags: Guaka.Flags, guakaArgs args: [String], run r: @escaping Run) {
		guakaCommand = cmd
		guakaFlags = flags
		guakaArgs = args
		run = r
	}
	
	func run(using context: CommandContext) throws -> Future<Void> {
		do    {return try run(guakaFlags, guakaArgs, context)}
		catch {guakaCommand.fail(statusCode: (error as NSError).code, errorMessage: error.legibleLocalizedDescription)}
	}
	
}
