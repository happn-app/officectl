/*
 * GlobalOptions.swift
 * officectl
 *
 * Created by François Lamboley on 10/06/2020.
 */

import Foundation

import ArgumentParser



struct GlobalOptions : ParsableArguments {
	
	enum Environment : ExpressibleByArgument {
		
		case development
		case testing
		
		case production
		
		init?(argument: String) {
			switch argument {
			case "dev", "development", nil: self = .development
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
	
	@Flag(name: .long, default: false, inversion: .prefixedEnableDisable, help: "Enable or disable interactive console (ncurses or Vapor’s activity console) for commands that have it.")
	var interactiveConsole: Bool
	
	@Option(name: .long, help: "The path to the static data dir (containing the static resources for officectl).")
	var staticDataDir: String?
	
}
