/*
 * ConnectorCredentialsFile.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/11/24.
 */

import Foundation



struct ConnectorCredentialsFile : Sendable, Decodable {
	
	let type: String
	let projectId: String
	let privateKeyId: String
	let privateKey: String
	let clientEmail: String
	let clientId: String
	let authUri: URL
	let tokenUri: URL
	let authProviderX509CertUrl: URL
	let clientX509CertUrl: URL
	
	enum CodingKeys : String, CodingKey {
		
		case type
		case projectId = "project_id"
		case privateKeyId = "private_key_id"
		case privateKey = "private_key"
		case clientEmail = "client_email"
		case clientId = "client_id"
		case authUri = "auth_uri"
		case tokenUri = "token_uri"
		case authProviderX509CertUrl = "auth_provider_x509_cert_url"
		case clientX509CertUrl = "client_x509_cert_url"
		
	}
	
}
