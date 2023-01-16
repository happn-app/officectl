/*
 * officectl.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/12.
 */

import Foundation

import ArgumentParser
import CLTLogger
import Logging



@main
struct Officectl : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Manage multiple directories.",
		subcommands: [
			Users.self
		]
	)
	
	struct Options : ParsableArguments {
		
		@Option(name: .long, help: "Override the verbosity defined in the configuration. If no verbosity is defined in the conf, the default level is warning. Overrides the --verbose option.")
		var verbosity: Logger.Level?
		
		@Flag(name: .shortAndLong, inversion: .prefixedNo, help: "Shortcut to set the verbosity. When on, verbosity is set to debug, when off it is set to warning. Overridden by the --verbosity option.")
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
	
	@OptionGroup()
	var options: Options
	
}


extension Officectl.Options {
	
	static private(set) var logger: Logger = {
		Logger(label: "com.happn.officectl")
	}()
	
	func bootstrap() {
		let (logLevel, shouldWarn) = resolvedVerbosityAndShouldWarnAboutVerbosity
		LoggingSystem.bootstrap{ id in
			/* Note: CLTLoggers do not have IDs, so we do not use the id parameter of the handler. */
			var ret = CLTLogger()
			ret.logLevel = logLevel
			return ret
		}
		if shouldWarn {
			logger.warning("Got both --verbose and --verbosity options. Ignoring --verbose.")
		}
	}
	
	var logger: Logger {
		Self.logger
	}
	
	/* For info, you should use the logger var instead. */
	var resolvedVerbosity: Logger.Level {
		return resolvedVerbosityAndShouldWarnAboutVerbosity.level
	}
	
	private var resolvedVerbosityAndShouldWarnAboutVerbosity: (level: Logger.Level, bothVerboseAndVerbosityWereDefined: Bool) {
		let logLevel: Logger.Level
		var shouldWarn = false
		switch (verbose, verbosity) {
			case let (.some,    verbosity?): shouldWarn = true; fallthrough
			case let (nil,      verbosity?): logLevel = verbosity
			case let (verbose?, nil):        logLevel = (verbose ? .debug : .warning)
			case     (nil,      nil):        logLevel = .warning
		}
		return (logLevel, shouldWarn)
	}
	
}
