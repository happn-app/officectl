/*
 * Config.swift
 * officectl-odproxy
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import OpenDirectoryOffice



struct AppConfig : Decodable {
	
	var serverConfig: ServerConfig
	
	var openDirectoryConfig: OpenDirectoryServiceConfig.ConnectorSettings
	
	enum CodingKeys : String, CodingKey {
		
		case serverConfig = "server_config"
		case openDirectoryConfig = "open_directory_config"
		
	}
	
}


struct ServerConfig : Decodable {
	
	var hostname: String?
	var port: Int?
	
	var secret: String
	var signatureURLPathPrefixTransform: VerifySignatureMiddleware.SignatureURLPathPrefixTransform?
	
	enum CodingKeys : String, CodingKey {
		case hostname
		case port
		case secret
		case signatureURLPathPrefixTransform = "signature_url_path_prefix_transform"
	}
	
}
