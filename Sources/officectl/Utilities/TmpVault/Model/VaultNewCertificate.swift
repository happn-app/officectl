/*
 * VaultNewCertificate.swift
 * officectl
 *
 * Created by François Lamboley on 2022/09/28.
 * 
 */

import Foundation



struct VaultNewCertificate : Decodable {
	
	var certificate: String
	var issuingCa: String
	var caChain: [String]
	var privateKey: String
	
}
