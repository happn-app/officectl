/*
 * officectl.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/12.
 */

import Foundation
#if canImport(System)
import System
#else
import SystemPackage
#endif

import ArgumentParser
import CLTLogger
import Logging
import RetryingOperation
import URLRequestOperation
import TOMLDecoder
import XDG

import OfficeKit
import GitHubOffice
import GoogleOffice
import HappnOffice
import LDAPOffice
import Office365Office
import OfficeKitOffice
#if canImport(OpenDirectoryOffice)
import OpenDirectoryOffice
#endif
import VaultPKIOffice



@main
struct Officectl : AsyncParsableCommand {
	
	static var configuration = CommandConfiguration(
		abstract: "Manage multiple directories.",
		subcommands: [
			Users.self,
			Server.self
		]
	)
	
	struct Options : ParsableArguments {
		
		@Option(name: .long, help: "Override the verbosity defined in the configuration. If no verbosity is defined in the conf, the default level is notice for production environment, info for development environment. Overrides the --verbose option.")
		var verbosity: Logger.Level?
		
		@Flag(name: .shortAndLong, inversion: .prefixedNo, help: "Shortcut to set the verbosity. When on, verbosity is set to debug, when off it is set to warning. Overridden by the --verbosity option.")
		var verbose: Bool?
		
		@Flag(name: .long, inversion: .prefixedNo, help: "By default, logs are printed on stderr. Use this option to print to stdout instead.")
		var logToStdout: Bool = false
		
		@Option(name: .long, help: "Override the environment in which to run the program (dev or prod). If no environment is defined, the default value is development.")
		var env: Environment?
		
		@Option(name: .long, help: "The path to an officectl config file. By default we use `$XDG_CONFIG_DIRS/officectl/config.toml`.")
		var configFile: FilePath?
		
		@Option(name: .long, help: "Override the path to the static data dir. If not defined either in the CLI options or in the config file, we use `$XDG_DATA_DIRS/officectl/`.")
		var staticDataDir: FilePath?
		
		/* Could be in the config file, maybe. */
		@Flag(name: .long, inversion: .prefixedEnableDisable, help: "Enable or disable interactive console (ncurses or Vapor’s activity console) for commands that have it.")
		var interactiveConsole = true
		
		@Flag(name: .shortAndLong, help: "Do not ask question (when a question would have been asked, yes is answered).")
		var yes: Bool = false
		
		/* We must do this because otherwise Swift complains that the struct is not Decodable because of the storage var.
		 * Another solution would be to have a static storage instead, maybe even outside of Options, but an instance var is better. */
		enum CodingKeys : CodingKey {
			case verbosity
			case verbose
			case logToStdout
			case env
			case configFile
			case staticDataDir
			case interactiveConsole
			case yes
		}
		
		fileprivate let storage = Storage()
		fileprivate final class Storage {
			/* None of these properties can be accessed before the bootstrap. */
			
			var conf: Conf?
			var logger: Logger!
			var officeKitServices: OfficeKitServices!
			
		}
		
	}
	
	struct ServiceSearchSelectionOptions : ParsableArguments {
		
		@Option(name: .long, help: "Comma-separated list of service IDs. Select in which services the given ID should be searched for. If unset, all services are searched.")
		var idSearchServices: String?
		
	}
	
	@OptionGroup()
	var options: Options
	@OptionGroup()
	var serviceSearchSelectionOptions: ServiceSearchSelectionOptions
	
}


extension Officectl.Options {
	
	func bootstrap() throws {
		/* *** CONF *** */
		let confPath = try configFile ?? {
			let dirs = try BaseDirectories(prefixAll: "officectl", runtimeDirHandling: .skipSetup)
			return try dirs.findConfigFile("config.toml")
		}()
		let conf = try confPath.flatMap{ try TOMLDecoder().decode(Conf.self, from: Data(contentsOf: URL(fileURLWithPath: $0.string))) }
		storage.conf = conf
		
		
		/* *** LOGGER *** */
		LoggingSystem.bootstrap({ id, metadataProvider in
			/* Note: CLTLoggers do not have IDs, so we do not use the id parameter of the handler. */
			var ret = CLTLogger(fd: !logToStdout ? .standardError : .standardOutput, metadataProvider: metadataProvider)
			ret.logLevel = resolvedLogLevel
			return ret
		}, metadataProvider: nil)
		storage.logger = Logger(label: "com.happn.officectl")
		
		if verbose != nil && verbosity != nil {
			logger.warning("Got both --verbose and --verbosity options. Ignoring --verbose.")
		}
		if confPath == nil {
			logger.error("Conf file not found. Continuing without services.")
		}
#if canImport(os)
		RetryingOperationConfig.oslog = nil
		URLRequestOperationConfig.oslog = nil
#endif
		RetryingOperationConfig.logger = nil
		URLRequestOperationConfig.logger = Logger(label: "URLRequestOperation")
		
		
		/* *** SET CA CERTS FILE FOR LDAP *** */
		if let path = conf?.misc.caCertsFile, let confPath {
			try LDAPConnector.setCA(URL(fileURLWithPath: path, isDirectory: false, relativeTo: URL(fileURLWithPath: confPath.string)).path)
		}
		
		
		/* *** OFFICEKIT SERVICE PROVIDERS *** */
		OfficeKitServices.providers[       GitHubService.providerID] =        GitHubService.self
		OfficeKitServices.providers[       GoogleService.providerID] =        GoogleService.self
		OfficeKitServices.providers[        HappnService.providerID] =         HappnService.self
		OfficeKitServices.providers[         LDAPService.providerID] =          LDAPService.self
		OfficeKitServices.providers[    Office365Service.providerID] =     Office365Service.self
		OfficeKitServices.providers[    OfficeKitService.providerID] =     OfficeKitService.self
#if canImport(OpenDirectoryOffice)
		OfficeKitServices.providers[OpenDirectoryService.providerID] = OpenDirectoryService.self
#endif
		OfficeKitServices.providers[     VaultPKIService.providerID] =      VaultPKIService.self
		
		/* *** OFFICEKIT SERVICES *** */
		var services = OfficeKitServices()
		for (serviceID, serviceDef) in conf?.services ?? [:] {
			guard let provider = OfficeKitServices.providers[serviceDef.providerID] else {
				logger.error("Cannot find provider ID for service.", metadata: [LMK.serviceID: "\(serviceID)", LMK.providerID: "\(serviceDef.providerID)"])
				throw ExitCode(1)
			}
			services.allServices[serviceID] = try provider.init(id: serviceID, name: serviceDef.serviceName, jsonConfig: serviceDef.config, workdir: (confPath?.removingLastComponent().string).flatMap(URL.init(fileURLWithPath:)))
		}
		if let authServiceID = conf?.servicesConf.authServiceID {
			guard let authService = services.allServices[authServiceID] as? any AuthenticatorService else {
				logger.error("Cannot find auth service for given auth service ID.", metadata: [LMK.serviceID: "\(authServiceID)"])
				throw ExitCode(1)
			}
			services.authService = authService
		}
		storage.officeKitServices = services
	}
	
	var resolvedLogLevel: Logger.Level {
		switch (verbose, verbosity) {
			case let (_,        verbosity?): return verbosity
			case let (verbose?, nil):        return (verbose ? .debug : .warning)
			case     (nil,      nil):        return conf?.logLevel ?? resolvedEnvironment.defaultLogLevel
		}
	}
	
	var resolvedEnvironment: Environment {
		env ?? conf?.environment ?? .development
	}
	
	var resolvedStaticDataDir: FilePath? {
		staticDataDir ?? conf?.staticDataDirPath
	}
	
	var officeKitServices: OfficeKitServices {
		return storage.officeKitServices
	}
	
	var logger: Logger {
		return storage.logger
	}
	
	var conf: Conf? {
		return storage.conf
	}
	
}
