/*
 * UserProperty+VaultPKI.swift
 * VaultPKIOffice
 *
 * Created by François Lamboley on 2023/01/26.
 * 
 */

import Foundation

import OfficeKit



public extension UserProperty {
	
	static let vaultPKI_certificateValidityStartDate = UserProperty(rawValue: "happn/vault-pki/certificate-validity-start-date")
	static let vaultPKI_certificateExpirationDate = UserProperty(rawValue: "happn/vault-pki/certificate-expiration-date")
	static let vaultPKI_certificateRevocationDate = UserProperty(rawValue: "happn/vault-pki/certificate-revocation-date")
	
}
