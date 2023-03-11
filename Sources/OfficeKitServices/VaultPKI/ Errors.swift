/*
 *  Errors.swift
 * VaultPKIOffice
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation

import OfficeKit



public enum VaultPKIOfficeError : Error, Sendable {
	
	case invalidPEM(pem: String)
	case invalidCRL(message: String)
	
	case foundInvalidCertificateWithNoDN
	case foundInvalidCertificateWithNoUnambiguousCNInDN(dn: LDAPDistinguishedName)
	case foundInvalidCertificateWithNoValidityStartDate(dn: LDAPDistinguishedName)
	case foundInvalidCertificateWithNoExpirationDate(dn: LDAPDistinguishedName)
	
}

typealias Err = VaultPKIOfficeError
