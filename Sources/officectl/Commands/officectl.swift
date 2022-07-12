/*
 * officectl.swift
 * officectl
 *
 * Created by François Lamboley on 2018/06/26.
 */

import Foundation

import ArgumentParser



@main
struct OfficectlRootCommand : AsyncParsableCommand {
	
	struct Options : ParsableArguments {
		
		enum Environment : ExpressibleByArgument {
			
			case development
			case testing
			
			case production
			
			init?(argument: String) {
				switch argument {
					case "dev", "development": self = .development
					case "prod", "production": self = .production
					case "test", "testing": self = .testing
					default: return nil
				}
			}
			
		}
		
		@Flag(name: .shortAndLong, inversion: .prefixedNo, help: "Control program verbosity.")
		var verbose: Bool?
		
		@Option(name: .long, help: "The environment in which to run the program. Must be one of “development” (default), “production” or “testing”.")
		var env: String?
		
		@Option(name: .long, help: "The path to an officectl config file. Defaults to ~/.config/officectl/officectl.yaml, then /etc/officectl/officectl.yaml and finally /usr/local/etc/officectl/officectl.yaml.")
		var configFile: String?
		
		@Flag(name: .long, inversion: .prefixedEnableDisable, help: "Enable or disable interactive console (ncurses or Vapor’s activity console) for commands that have it.")
		var interactiveConsole = true
		
		@Option(name: .long, help: "The path to the static data dir (containing the static resources for officectl).")
		var staticDataDir: String?
		
	}
	
	static var configuration = CommandConfiguration(
		commandName: "officectl",
		abstract: "Manage multiple directories.",
		subcommands: [
			GetTokenCommand.self,
			SyncCommand.self,
			
			ServerCommand.self,
			UserCommand.self,
			BackupCommand.self,
			
			ExperimentalCommand.self
		]
	)
	
	@OptionGroup()
	var globalOptions: Options
	
}
