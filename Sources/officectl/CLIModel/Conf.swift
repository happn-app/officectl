/*
 * Conf.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/16.
 */

import Foundation
#if canImport(System)
import System
#else
import SystemPackage
#endif

import Logging



/* We use Strings instead of FilePaths in the conf to avoid decoding issues (FilePath encoding is structured). */
struct Conf : Decodable, Sendable {
	
	var logLevel: Logger.Level?
	var environment: Environment?
	
	/* This should probably not exist.
	 * Certificates should be installed in the system, period.
	 * Only used for the LDAP service. */
	var caCertsFile: String?
	
	/* Not sure if this should be in the server config… for now only the server uses it anyway. */
	var staticDataDir: String?
	var staticDataDirPath: FilePath? {
		staticDataDir.flatMap{ FilePath($0) }
	}
	
	var serverConf: ServerConf?
	
	var servicesConf: ServicesConf
	var services: [String: ServiceDef]
	
	enum CodingKeys : String, CodingKey {
		case logLevel = "log_level"
		case environment
		
		case caCertsFile = "ca_certs_file"
		
		case staticDataDir = "static_data_dir"
		
		case serverConf = "server"
		
		case servicesConf = "services_conf"
		case services
	}
	
}
