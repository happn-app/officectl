/*
 * CertificateMetadata.swift
 * VaultPKIOffice
 *
 * Created by François Lamboley on 2023/02/16.
 */

import Foundation

@preconcurrency import ASN1Decoder



public struct CertificateMetadata : Sendable {
	
	public var cn: String
	/** `nil` if the certif is not generated yet (description of a future certif). */
	public var certifID: String?
	
	public var keyUsageHasServerAuth: Bool
	public var keyUsageHasClientAuth: Bool
	
	public var validityStartDate: Date
	public var expirationDate: Date
	/**
	 The date at which the certificate has been revoked, `nil` if it was not revoked.
	 
	 Of course, the revocation date is not a part of a certificate per se.
	 We init a “parsed certificate” with a revocation list to set this variable. */
	public var revocationDate: Date?
	
	/**
	 For info.
	 Might be `nil` if there are no underlying certificate (`CertificateMetadata` initialized without one).
	 
	 We might make that public later, but in theory we should not have to.
	 We might also remove the property altogether… */
	var underlyingCertif: X509Certificate?
	
	public init(
		cn: String, certifID: String?,
		keyUsageHasServerAuth: Bool, keyUsageHasClientAuth: Bool,
		validityStartDate: Date, expirationDate: Date, revocationDate: Date? = nil,
		underlyingCertif: X509Certificate? = nil
	) {
		self.cn = cn
		self.certifID = certifID
		self.keyUsageHasServerAuth = keyUsageHasServerAuth
		self.keyUsageHasClientAuth = keyUsageHasClientAuth
		self.validityStartDate = validityStartDate
		self.expirationDate = expirationDate
		self.revocationDate = revocationDate
		self.underlyingCertif = underlyingCertif
	}
	
	public func isRevoked(at date: Date = Date()) -> Bool {
		return revocationDate.flatMap{ $0 <= date } ?? false
	}
	
	public func isExpired(at date: Date = Date()) -> Bool {
		return expirationDate <= date
	}
	
	public func isValid(at date: Date = Date()) -> Bool {
		return (
			!isRevoked(at: date) &&
			!isExpired(at: date) &&
			validityStartDate <= date
		)
	}
	
}
