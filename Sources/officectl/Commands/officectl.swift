/*
 * officectl.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/12.
 */

import Foundation

import ArgumentParser
import Logging



@main
struct Officectl : AsyncParsableCommand {
	
	struct Options : ParsableArguments {
		
		@Option(name: .long, help: "Override the verbosity defined in the configuration. If no verbosity is defined in the conf, the default level is warning.")
		var verbosity: Logger.Level?
		
		@Flag(name: .shortAndLong, inversion: .prefixedNo, help: "Shortcut to set the verbosity. When on, verbosity is set to debug, when off it is set to warning.")
		var verbose: Bool?
		
		@Option(name: .long, help: "Override the environment in which to run the program (dev or prod).")
		var env: Environment?
		
		@Option(name: .long, help: "The path to an officectl config file. By default we use `$XDG_CONFIG_DIRS/officectl/config.toml`.")
		var configFile: String?
		
		@Option(name: .long, help: "Override the path to the static data dir. If not defined either in the CLI options or in the config file, we use `$XDG_DATA_DIRS/officectl/`.")
		var staticDataDir: String?
		
		/* Could be in the config file, maybe. */
		@Flag(name: .long, inversion: .prefixedEnableDisable, help: "Enable or disable interactive console (ncurses or Vapor’s activity console) for commands that have it.")
		var interactiveConsole = true
		
	}
	
	static var configuration = CommandConfiguration(
		abstract: "Manage multiple directories.",
		subcommands: [
			Users.self
		]
	)
	
	@OptionGroup()
	var globalOptions: Options
	
}
