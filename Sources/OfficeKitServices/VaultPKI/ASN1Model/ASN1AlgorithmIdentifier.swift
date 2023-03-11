/*
 * ASN1AlgorithmIdentifier.swift
 * VaultPKIOffice
 *
 * Created by François Lamboley on 2023/03/11.
 */

import Foundation

import SwiftASN1



/* From swift-certificates (internal struct, cannot be used). */
/*
 * AlgorithmIdentifier  ::=  SEQUENCE  {
 *      algorithm               OBJECT IDENTIFIER,
 *      parameters              ANY DEFINED BY algorithm OPTIONAL  }
 */
struct ASN1AlgorithmIdentifier : DERImplicitlyTaggable, Hashable, Sendable {
	
	static var defaultIdentifier: ASN1Identifier {
		.sequence
	}
	
	var algorithm: ASN1ObjectIdentifier
	var parameters: ASN1Any?
	
	init(algorithm: ASN1ObjectIdentifier, parameters: ASN1Any?) {
		self.algorithm = algorithm
		self.parameters = parameters
	}
	
	init(derEncoded rootNode: ASN1Node, withIdentifier identifier: ASN1Identifier) throws {
		self = try DER.sequence(rootNode, identifier: identifier, { nodes in
			let algorithmOID = try ASN1ObjectIdentifier(derEncoded: &nodes)
			let parameters = nodes.next().map{ ASN1Any(derEncoded: $0) }
			
			return .init(algorithm: algorithmOID, parameters: parameters)
		})
	}
	
	func serialize(into coder: inout DER.Serializer, withIdentifier identifier: ASN1Identifier) throws {
		try coder.appendConstructedNode(identifier: identifier, { coder in
			try coder.serialize(algorithm)
			if let parameters {
				try coder.serialize(parameters)
			}
		})
	}
	
}
