/*
 * CloudflareZeroTrustUser+OfficeModel.swift
 * CloudflareZeroTrustOffice
 *
 * Created by François Lamboley on 2023/07/27.
 */

import Foundation

import Email

import OfficeKit



extension CloudflareZeroTrustUser : User {
	
	/** Two IDs are equal iif their seat ID are equal. */
	public struct ID : Hashable, Codable, Sendable, RawRepresentable, MightHaveEmail {
		
		public static let escape = "/"
		public static let separator = " #"
		
		public static func ==(lhs: ID, rhs: ID) -> Bool {
			return lhs.cfSeatID == rhs.cfSeatID
		}
		public func hash(into hasher: inout Hasher) {
			hasher.combine(cfSeatID)
		}
		
		public var cfSeatID: String
		public var email: Email?
		
		public init(cfSeatID: String, email: Email? = nil) {
			self.cfSeatID = cfSeatID
			self.email = email
		}
		
		public init?(rawValue: String) {
			self.init(rawValue: rawValue, forcedSeparator: nil, forcedEscape: nil)
		}
		
		/* For tests. */
		internal init?(rawValue: String, forcedSeparator: String?, forcedEscape: String?) {
			/* This code is awful. I know. */
			let escape = String((forcedEscape ?? Self.escape).reversed())
			let separator = String((forcedSeparator ?? Self.separator).reversed())
			var reversedAndSplit: [String]
			if #available(macOS 13.0, *) {
				reversedAndSplit = rawValue.reversed().split(separator: separator, omittingEmptySubsequences: false).reversed().map(String.init)
			} else {
				reversedAndSplit = String(rawValue.reversed()).components(separatedBy: String(separator)).reversed()
			}
			var seatID = ""
			var previousPartHasSuffix = true
			while previousPartHasSuffix, let curElement = reversedAndSplit.popLast() {
				previousPartHasSuffix = curElement.hasSuffix(escape)
				seatID += (seatID.isEmpty ? "" : String(separator)) + (previousPartHasSuffix ? String(curElement.dropLast(escape.count)) : curElement)
			}
			self.cfSeatID = String(seatID.reversed())
			if reversedAndSplit.isEmpty {
				self.email = nil
			} else {
				guard let e = Email(rawValue: reversedAndSplit.map{ String($0.reversed()) }.joined(separator: String(separator.reversed()))) else {
					return nil
				}
				self.email = e
			}
		}
		
		public var rawValue: String {
			return rawValue(forcedSeparator: nil, forcedEscape: nil)
		}
		
		/* For tests. */
		public func rawValue(forcedSeparator: String?, forcedEscape: String?) -> String {
			let escape = forcedEscape ?? Self.escape
			let separator = forcedSeparator ?? Self.separator
			/* There is no need to escape the semicolon in the email because we parse in reverse,
			 *  and once the separator has been found we use the rest of the string as the email.
			 * This is also why we put the escape token _after_ the separator in the replacement. */
			let escapedID = cfSeatID
				.replacingOccurrences(of: escape,    with: escape    + escape)
				.replacingOccurrences(of: separator, with: separator + escape)
			return (email.flatMap{ $0.rawValue + separator } ?? "") + escapedID
		}
		
	}
	
	public typealias UserIDType = ID
	public typealias PersistentUserIDType = String
	
	public init(oU_id userID: ID) {
		self.seatUID = userID.cfSeatID
		self.email = userID.email
		
		self.accessSeat = false
		self.gatewaySeat = false
	}
	
	public var oU_id: ID {
		return .init(cfSeatID: seatUID, email: email)
	}
	
	public var oU_persistentID: String? {
		return seatUID
	}
	
	public var oU_isSuspended: Bool? {
		return nil
	}
	
	public var oU_firstName: String? {
		if #available(macOS 13.0, *) {return name?.split(separator: #/\s/#, maxSplits: 1).first.flatMap(String.init)}
		else                         {return name?.split(separator: " ",    maxSplits: 1).first.flatMap(String.init)}
	}
	
	public var oU_lastName: String? {
		if #available(macOS 13.0, *) {return name?.split(separator: #/\s/#, maxSplits: 1).last.flatMap(String.init)}
		else                         {return name?.split(separator: " ",    maxSplits: 1).last.flatMap(String.init)}
	}
	
	public var oU_nickname: String? {
		return nil
	}
	
	public var oU_emails: [Email]? {
		return email.flatMap{ [$0] }
	}
	
	public var oU_nonStandardProperties: Set<String> {
		return []
	}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> Sendable? {
		switch UserProperty(rawValue: property) {
			/* We do not support any non-standard properties for now. */
			default: return nil
		}
	}
	
	public mutating func oU_setValue<V : Sendable>(_ newValue: V?, forProperty property: UserProperty, convertMismatchingTypes convert: Bool) -> PropertyChangeResult {
		/* Technically we could change the accessSeat and gatewaySeat values,
		 *  but for now we do not have non-standard properties for these
		 *  and we only allow deleting a user (which is the same as setting both these values to false). */
		Conf.logger?.info("Cannot change any property of a Cloudflare ZeroTrust User.")
		return .failure(.readOnlyProperty)
	}
}
