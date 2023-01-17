/*
 * Conf.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/16.
 */

import Foundation
#if canImport(System)
@preconcurrency import System
#else
@preconcurrency import SystemPackage
#endif

import Logging



struct Conf : Decodable, Sendable {
	
	var logLevel: Logger.Level?
	var environment: Environment?
	
	/* This should probably not exist.
	 * Certificates should be installed in the system, period.
	 * Only used for the LDAP service. */
	var caCertsFile: FilePath?
	
	/* Not sure if this should be in the server config… for now only the server uses it anyway. */
	var staticDataDir: FilePath?
	
	var serverConf: ServerConf?
	
	var servicesConf: ServicesConf
	var services: [String: ServiceDef]
	
	/* Custom init from decoder because FilePath has a weird af way to encode (and thus decode) itself.
	 * We could also use a String for the static data dir… */
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.logLevel      = try container.decodeIfPresent(Logger.Level.self, forKey: .logLevel)
		self.environment   = try container.decodeIfPresent( Environment.self, forKey: .environment)
		self.caCertsFile   = try container.decodeIfPresent(      String.self, forKey: .caCertsFile).flatMap(FilePath.init)
		self.staticDataDir = try container.decodeIfPresent(      String.self, forKey: .staticDataDir).flatMap(FilePath.init)
		self.serverConf    = try container.decodeIfPresent(  ServerConf.self, forKey: .serverConf)
		self.servicesConf  = try container.decode(         ServicesConf.self, forKey: .servicesConf)
		self.services      = try container.decode( [String: ServiceDef].self, forKey: .services)
	}
	
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
