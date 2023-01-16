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
	
	/* Not sure if this should be in the server config… for now only the server uses it anyway. */
	var staticDataDir: FilePath?
	
	var serverConf: ServerConf?
	
	/* Custom init from decoder because FilePath has a weird af way to encode (and thus decode) itself.
	 * We could also use a String for the static data dir… */
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.logLevel      = try container.decodeIfPresent(Logger.Level.self, forKey: .logLevel)
		self.environment   = try container.decodeIfPresent( Environment.self, forKey: .environment)
		self.staticDataDir = try container.decodeIfPresent(      String.self, forKey: .staticDataDir).flatMap(FilePath.init)
		self.serverConf    = try container.decodeIfPresent(  ServerConf.self, forKey: .serverConf)
	}
	
	enum CodingKeys : String, CodingKey {
		case logLevel = "log_level"
		case environment
		
		case staticDataDir = "static_data_dir"
		
		case serverConf = "server"
	}
	
}
