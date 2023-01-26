/*
 * VaultPKIUser.swift
 * VaultPKIOffice
 *
 * Created by François Lamboley on 2023/01/26.
 */

import Foundation

@preconcurrency import ASN1Decoder
import Email

import OfficeKit



public struct VaultPKIUser : User {
	
	public static var defaultCertificateValidityLength: TimeInterval = 365.2425 /* 1y */
	
	public typealias UserIDType = String
	public typealias PersistentUserIDType = String
	
	public init(oU_id userID: String) {
		self.oU_id = userID
		self.validityStartDate = .now
		self.expirationDate = .now + Self.defaultCertificateValidityLength
	}
	
	public var oU_id: String
	public var oU_persistentID: String?
	
	public var oU_isSuspended: Bool? {!isValid()}
	
	public var oU_firstName: String? {nil}
	public var oU_lastName: String? {nil}
	public var oU_nickname: String? {nil}
	
	public var oU_emails: [Email]? {nil}
	
	public var validityStartDate: Date
	public var expirationDate: Date
	public var revocationDate: Date?
	
	public var certif: X509Certificate?
	
	public func isValid(at date: Date = .now) -> Bool {
		return (
			(revocationDate.flatMap{ $0 > date } ?? true) &&
			expirationDate > date &&
			validityStartDate <= date
		)
	}
	
	public var oU_nonStandardProperties: Set<String> {
		return [
			UserProperty.vaultPKI_certificateValidityStartDate.rawValue,
			UserProperty.vaultPKI_certificateExpirationDate.rawValue,
			UserProperty.vaultPKI_certificateRevocationDate.rawValue
		]
	}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> Sendable? {
		switch property {
			case UserProperty.vaultPKI_certificateValidityStartDate.rawValue: return validityStartDate
			case UserProperty.vaultPKI_certificateExpirationDate.rawValue:    return expirationDate
			case UserProperty.vaultPKI_certificateRevocationDate.rawValue:    return revocationDate
			default:
				return nil
		}
	}
	
	public mutating func oU_setValue<V : Sendable>(_ newValue: V?, forProperty property: UserProperty, convertMismatchingTypes convert: Bool) -> PropertyChangeResult {
		Conf.logger?.info("Cannot change any property of a VaultPKI User.")
		return .failure(.readOnlyProperty)
	}
	
}
