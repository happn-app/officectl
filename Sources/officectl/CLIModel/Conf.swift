/*
 * Conf.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/16.
 */

import Foundation
import OfficeModelCore
#if canImport(System)
import System
#else
import SystemPackage
#endif

import ArgumentParser
import Logging



/* We use Strings instead of FilePaths in the conf to avoid decoding issues (FilePath encoding is structured). */
struct Conf : Decodable, Sendable {
	
	enum LogHandler : String, LosslessStringConvertible, Decodable, Sendable, ExpressibleByArgument {
		
		case cltLogger = "clt-logger"
		case jsonLogger = "json-logger"
		
		init?(_ description: String) {
			self.init(rawValue: description)
		}
		
		init?(argument: String) {
			self.init(argument)
		}
		
		var description: String {
			return rawValue
		}
		
	}
	
	var environment: Environment?
	
	var logHandler: LogHandler?
	var logLevel: Logger.Level?
	
	/* Not sure if this should be in the server config… for now only the server uses it anyway. */
	var staticDataDir: String?
	var staticDataDirPath: FilePath? {
		staticDataDir.flatMap{ FilePath($0) }
	}
	
	var misc: Misc
	
	var serverConf: ServerConf?
	
	var servicesConf: ServicesConf
	var services: [Tag: ServiceDef]
	
	struct Misc : Decodable, Sendable {
		
		/* This should probably not exist.
		 * Certificates should be installed in the system, period.
		 * Only used for the LDAP service. */
		var caCertsFile: String?
		
		/* I’m not 100% sure where to put this.
		 * It’s not something that could be directly in the VaultPKI service because we need a way to override the value.
		 * It’s only a first line of defense against the non-admin users, not an actual part of the service. */
		var maxExpirationDelayBeforeAllowingReissuance: TimeInterval
		
		var happnConsolePermGroups: [String: String]?
		
		enum CodingKeys : String, CodingKey {
			case caCertsFile = "ca_certs_file"
			case maxExpirationDelayBeforeAllowingReissuance = "max_expiration_delay_before_allowing_reissuance"
			case happnConsolePermGroups = "happn_console_perm_groups"
		}
		
	}
	
	
	enum CodingKeys : String, CodingKey {
		case environment
		
		case logHandler = "log_handler"
		case logLevel = "log_level"

		case staticDataDir = "static_data_dir"
		
		case misc
		
		case serverConf = "server"
		
		case servicesConf = "services_conf"
		case services
	}
	
}
