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
import TOMLDecoder
import XDG

import ServiceKit



@main
struct Officectl : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Manage multiple directories.",
		subcommands: [
			Users.self,
			Server.self
		]
	)
	
	static private(set) var services = Services()
	
	struct Options : ParsableArguments {
		
		@Option(name: .long, help: "Override the verbosity defined in the configuration. If no verbosity is defined in the conf, the default level is notice for production environment, info for development environment. Overrides the --verbose option.")
		var verbosity: Logger.Level?
		
		@Flag(name: .shortAndLong, inversion: .prefixedNo, help: "Shortcut to set the verbosity. When on, verbosity is set to debug, when off it is set to warning. Overridden by the --verbosity option.")
		var verbose: Bool?
		
		@Option(name: .long, help: "Override the environment in which to run the program (dev or prod). If no environment is defined, the default value is development.")
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
	
	func bootstrap() throws {
		/* *** CONF *** */
		let confPath = try configFile ?? {
			let dirs = try BaseDirectories(prefixAll: "officectl", runtimeDirHandling: .skipSetup)
			return try dirs.findConfigFile("config.toml")?.string
		}()
		let conf = try confPath.flatMap{ try TOMLDecoder().decode(Conf.self, from: Data(contentsOf: URL(fileURLWithPath: $0))) }
		Officectl.services.register{ conf } /* We want to return always the same conf. */
		
		/* *** LOGGER *** */
		LoggingSystem.bootstrap{ id in
			/* Note: CLTLoggers do not have IDs, so we do not use the id parameter of the handler. */
			var ret = CLTLogger()
			ret.logLevel = resolvedLogLevel
			return ret
		}
		let logger = Logger(label: "com.happn.officectl")
		Officectl.services.register{ logger } /* We want to return always the same logger. */
		
		if verbose != nil && verbosity != nil {
			logger.warning("Got both --verbose and --verbosity options. Ignoring --verbose.")
		}
		if confPath == nil {
			logger.error("Conf file not found. Continuing without services.")
		}
	}
	
	var resolvedLogLevel: Logger.Level {
		switch (verbose, verbosity) {
			case let (_,        verbosity?): return verbosity
			case let (verbose?, nil):        return (verbose ? .debug : .warning)
			case     (nil,      nil):        return conf?.logLevel ?? resolvedEnvironment.defaultLogLevel
		}
	}
	
	var logger: Logger {
		try! Officectl.services.make()
	}
	
	var conf: Conf? {
		try! Officectl.services.make()
	}
	
	var resolvedEnvironment: Environment {
		env ?? conf?.environment ?? .development
	}
	
}
