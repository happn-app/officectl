/*
 * CertificateMetadata.swift
 * VaultPKIOffice
 *
 * Created by François Lamboley on 2023/02/16.
 */

import Foundation

@preconcurrency import ASN1Decoder



public struct CertificateMetadata : Sendable {
	
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
	
	public init(keyUsageHasServerAuth: Bool, keyUsageHasClientAuth: Bool, validityStartDate: Date, expirationDate: Date, revocationDate: Date? = nil, underlyingCertif: X509Certificate? = nil) {
		self.keyUsageHasServerAuth = keyUsageHasServerAuth
		self.keyUsageHasClientAuth = keyUsageHasClientAuth
		self.validityStartDate = validityStartDate
		self.expirationDate = expirationDate
		self.revocationDate = revocationDate
		self.underlyingCertif = underlyingCertif
	}
	
	public func isValid(at date: Date = Date()) -> Bool {
		return (
			(revocationDate.flatMap{ $0 > date } ?? true) &&
			expirationDate > date &&
			validityStartDate <= date
		)
	}
	
}
