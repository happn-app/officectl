/*
 * VaultPKIUser.swift
 * VaultPKIOffice
 *
 * Created by François Lamboley on 2023/01/26.
 */

import Foundation

import ASN1Decoder
import Email

import OfficeKit



public struct VaultPKIUser : User {
	
	public static var defaultCertificateValidityLength: TimeInterval = 365.2425 /* 1y */
	
	public typealias UserIDType = String
	public typealias PersistentUserIDType = String
	
	public init(oU_id userID: String) {
		self.oU_id = userID
		
		let now = Date() /* .now is not available on Linux apparently… but compilation pass when we use it! */
		self.certificateMetadata = .init(
			keyUsageHasServerAuth: false,
			keyUsageHasClientAuth: true,
			validityStartDate: now,
			expirationDate: now + Self.defaultCertificateValidityLength
		)
	}
	
	internal init(cn: String, certifID: String, certificateMetadata: CertificateMetadata) {
		if !certificateMetadata.keyUsageHasClientAuth {
			Conf.logger?.error("VaultPKIUser init’d with a certificate whose key usage does not have client auth. This is an internal logic error in the VaultPKIOffice module.", metadata: ["user_id": "\(cn)", "certificate_id": "\(certifID)"])
		}
		self.oU_id = cn
		self.oU_persistentID = certifID
		self.certificateMetadata = certificateMetadata
	}
	
	public var oU_id: String
	public var oU_persistentID: String?
	
	public var oU_isSuspended: Bool? {!certificateMetadata.isValid()}
	
	public var oU_firstName: String? {nil}
	public var oU_lastName: String? {nil}
	public var oU_nickname: String? {nil}
	
	public var oU_emails: [Email]? {nil}
	
	public internal(set) var certificateMetadata: CertificateMetadata
	
	public var oU_nonStandardProperties: Set<String> {
		return [
			UserProperty.vaultPKI_certificateValidityStartDate.rawValue,
			UserProperty.vaultPKI_certificateExpirationDate.rawValue,
			UserProperty.vaultPKI_certificateRevocationDate.rawValue
		]
	}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> Sendable? {
		switch property {
			case UserProperty.vaultPKI_certificateValidityStartDate.rawValue: return certificateMetadata.validityStartDate
			case UserProperty.vaultPKI_certificateExpirationDate.rawValue:    return certificateMetadata.expirationDate
			case UserProperty.vaultPKI_certificateRevocationDate.rawValue:    return certificateMetadata.revocationDate
			default:
				return nil
		}
	}
	
	public mutating func oU_setValue<V : Sendable>(_ newValue: V?, forProperty property: UserProperty, convertMismatchingTypes convert: Bool) -> PropertyChangeResult {
		Conf.logger?.info("Cannot change any property of a VaultPKI User.")
		return .failure(.readOnlyProperty)
	}
	
}
