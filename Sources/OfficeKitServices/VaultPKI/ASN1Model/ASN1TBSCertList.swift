/*
 * ASN1TBSCertList.swift
 * VaultPKIOffice
 *
 * Created by François Lamboley on 2023/03/11.
 */

import Foundation

import SwiftASN1
import X509



/*
 * TBSCertList  ::=  SEQUENCE  {
 *      version                 Version OPTIONAL,
 *                                   -- if present, MUST be v2
 *      signature               AlgorithmIdentifier,
 *      issuer                  Name,
 *      thisUpdate              Time,
 *      nextUpdate              Time OPTIONAL,
 *      revokedCertificates     SEQUENCE OF SEQUENCE  {
 *           userCertificate         CertificateSerialNumber,
 *           revocationDate          Time,
 *           crlEntryExtensions      Extensions OPTIONAL
 *                                    -- if present, version MUST be v2
 *                                }  OPTIONAL,
 *      crlExtensions           [0]  EXPLICIT Extensions OPTIONAL
 *                                    -- if present, version MUST be v2
 *                                }
 *
 * Version  ::=  INTEGER  {  v1(0), v2(1), v3(2)  }
 *
 * CertificateSerialNumber  ::=  INTEGER
 *
 * Extensions  ::=  SEQUENCE SIZE (1..MAX) OF Extension
 *
 * Extension  ::=  SEQUENCE  {
 *      extnID      OBJECT IDENTIFIER,
 *      critical    BOOLEAN DEFAULT FALSE,
 *      extnValue   OCTET STRING
 *                  -- contains the DER encoding of an ASN.1 value
 *                  -- corresponding to the extension type identified
 *                  -- by extnID
 *      }
 */
struct ASN1TBSCertList : DERImplicitlyTaggable, Sendable {
	
	static let defaultIdentifier: ASN1Identifier = .sequence
	
	enum Version : Int, Sendable, DERImplicitlyTaggable {
		
		case v1 = 0
		case v2 = 1
		case v3 = 2
		
		static let defaultIdentifier: ASN1Identifier = .integer
		
		init(derEncoded rootNode: ASN1Node, withIdentifier identifier: ASN1Identifier) throws {
			let ia = try ArraySlice<UInt8>(derEncoded: rootNode, withIdentifier: identifier)
			let error = ASN1Error.invalidASN1Object(reason: "Invalid version")
			guard let i = ia.onlyElement else {
				throw error
			}
			switch i {
				case 0: self = .v1
				case 1: self = .v2
				case 2: self = .v3
				default: throw error
			}
		}
		
		func serialize(into coder: inout DER.Serializer, withIdentifier identifier: ASN1Identifier) throws {
			try coder.appendConstructedNode(identifier: identifier, { coder in
				try coder.serialize(ArraySlice([UInt8(rawValue)]))
			})
		}
		
	}
	
	struct RevokedCertificate : DERImplicitlyTaggable, Sendable {
		
		static var defaultIdentifier: SwiftASN1.ASN1Identifier = .sequence
		
		var userCertificate: Certificate.SerialNumber
		var revocationDate: ASN1Time
		/* Will always contain at least one element if non-nil. */
		var crlEntryExtensions: Certificate.Extensions?
		
		init(userCertificate: Certificate.SerialNumber, revocationDate: ASN1Time, crlEntryExtensions: Certificate.Extensions? = nil) {
			self.userCertificate = userCertificate
			self.revocationDate = revocationDate
			self.crlEntryExtensions = crlEntryExtensions
		}
		
		init(derEncoded rootNode: ASN1Node, withIdentifier identifier: ASN1Identifier) throws {
			self = try DER.sequence(rootNode, identifier: identifier, { nodes in
				let cert = try ArraySlice<UInt8>(derEncoded: &nodes)
				let date = try ASN1Time(derEncoded: &nodes)
				let exts = try nodes.next().flatMap{ rootNode -> [Certificate.Extension] in
					try DER.sequence(identifier: .sequence, rootNode: rootNode)
				}
				guard !(exts?.isEmpty ?? false) else {
					throw ASN1Error.invalidASN1Object(reason: "Extensions is present but empty.")
				}
				
				return .init(
					userCertificate: Certificate.SerialNumber(bytes: cert),
					revocationDate: date,
					crlEntryExtensions: exts.flatMap(Certificate.Extensions.init)
				)
			})
		}
		
		func serialize(into coder: inout DER.Serializer, withIdentifier identifier: ASN1Identifier) throws {
			try coder.appendConstructedNode(identifier: identifier, { coder in
				try coder.serialize(userCertificate.bytes)
				try coder.serialize(revocationDate)
				if let exts = crlEntryExtensions {
					try coder.appendConstructedNode(identifier: .sequence, { coder in
						for idx in exts.startIndex..<exts.endIndex {
							try coder.serialize(exts[idx])
						}
					})
				}
			})
		}
		
	}
	
	var version: Version?
	var signature: ASN1AlgorithmIdentifier
	var issuer: DistinguishedName
	var thisUpdate: ASN1Time
	var nextUpdate: ASN1Time?
	var revokedCertificates: [RevokedCertificate]?
	/* Will always contain at least one element if non-nil. */
	var crlExtensions: Certificate.Extensions?
	
	init(version: Version? = nil, signature: ASN1AlgorithmIdentifier, issuer: DistinguishedName, thisUpdate: ASN1Time, nextUpdate: ASN1Time? = nil, revokedCertificates: [RevokedCertificate]? = nil, crlExtensions: Certificate.Extensions? = nil) {
		self.version = version
		self.signature = signature
		self.issuer = issuer
		self.thisUpdate = thisUpdate
		self.nextUpdate = nextUpdate
		self.revokedCertificates = revokedCertificates
		self.crlExtensions = crlExtensions
	}
	
	init(derEncoded rootNode: ASN1Node, withIdentifier identifier: ASN1Identifier) throws {
		self = try DER.sequence(rootNode, identifier: identifier, { nodes in
			let version: Version? = try DER.optionalImplicitlyTagged(&nodes)
			guard version == nil || version == .v2 else {
				throw ASN1Error.invalidASN1Object(reason: "Invalid version \(version!) for CRL")
			}
			let signature = try ASN1AlgorithmIdentifier(derEncoded: &nodes)
			let issuer = try DistinguishedName(derEncoded: &nodes)
			let thisUpdate = try ASN1Time(derEncoded: &nodes)
			let nextUpdate: ASN1Time?
			do                                                            {nextUpdate = try ASN1Time(derEncoded: &nodes)}
			catch let e as ASN1Error where e.code == .unexpectedFieldType {nextUpdate = nil}
			let revokedCertificates: [RevokedCertificate]?
			let nodeAfterRevokedCertificates: ASN1Node?
			if let node = nodes.next() {
				/* We have a next node.
				 * Is it the extensions node or the revoked certificates node? */
				if node.identifier.tagClass == .contextSpecific && node.identifier.tagNumber == 0 {
					/* Apparently, yes. */
					revokedCertificates = nil
					nodeAfterRevokedCertificates = node
				} else {
					/* It seems not, we should decode the revoked certificates list. */
					revokedCertificates = try DER.sequence(identifier: .sequence, rootNode: node)
					nodeAfterRevokedCertificates = nodes.next()
				}
			} else {
				revokedCertificates = nil
				nodeAfterRevokedCertificates = nil
			}
			let exts = try nodeAfterRevokedCertificates.flatMap{ node -> [Certificate.Extension] in
				/* Logic is from `DER.sequence(of:identifier:rootNode:)`. */
				guard case .constructed(let nodes) = node.content else {
					/* This error is an internal parser error: the tag above is always constructed. */
					preconditionFailure("Explicit tags are always constructed")
				}
				var iterator = nodes.makeIterator()
				guard let node = iterator.next(), iterator.next() == nil else {
					throw ASN1Error.invalidASN1Object(reason: "Too many child nodes in optionally tagged node of Certificate.Extension.")
				}
				return try DER.sequence(identifier: .sequence, rootNode: node)
			}
			guard !(exts?.isEmpty ?? false) else {
				throw ASN1Error.invalidASN1Object(reason: "Extensions is present but empty.")
			}
			guard version == .v2 || (revokedCertificates?.allSatisfy{ $0.crlEntryExtensions == nil } ?? true && exts == nil) else {
				throw ASN1Error.invalidASN1Object(reason: "Got extensions but version is not v2.")
			}
			
			return .init(
				version: version,
				signature: signature,
				issuer: issuer,
				thisUpdate: thisUpdate,
				nextUpdate: nextUpdate,
				revokedCertificates: revokedCertificates,
				crlExtensions: exts.flatMap(Certificate.Extensions.init)
			)
		})
	}
	
	func serialize(into coder: inout DER.Serializer, withIdentifier identifier: ASN1Identifier) throws {
		try coder.appendConstructedNode(identifier: identifier, { coder in
			if let version {try coder.serialize(version)}
			try coder.serialize(signature)
			try coder.serialize(issuer)
			try coder.serialize(thisUpdate)
			if let nextUpdate          {try coder.serialize(nextUpdate)}
			if let revokedCertificates {
				try coder.appendConstructedNode(identifier: .sequence, { coder in
					for idx in revokedCertificates.startIndex..<revokedCertificates.endIndex {
						try coder.serialize(revokedCertificates[idx])
					}
				})
			}
			if let exts = crlExtensions {
				try coder.serialize(explicitlyTaggedWithTagNumber: 0, tagClass: .contextSpecific, { coder in
					for idx in exts.startIndex..<exts.endIndex {
						try coder.serialize(exts[idx])
					}
				})
			}
		})
	}
	
}
