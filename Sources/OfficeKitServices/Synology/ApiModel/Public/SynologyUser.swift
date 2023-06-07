/*
 * SynologyUser.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation

import Email
import UnwrapOrThrow

import OfficeKit



public struct SynologyUser : Sendable, Hashable, Codable {
	
	public enum Expiration : Hashable, Codable, Sendable {
		
		static let dateFormatter: DateFormatter = {
			let ret = DateFormatter()
			ret.calendar = Calendar(identifier: .gregorian)
			ret.locale = Locale(identifier: "en_US_POSIX")
			ret.dateFormat = "yyyy/M/d"
			return ret
		}()
		
		case none
		case now
		case date(Date)
		
		public init(from decoder: Decoder) throws {
			let container = try decoder.singleValueContainer()
			switch try container.decode(String.self) {
				case "normal": self = .none
				case "now":    self = .now
				case let dateStr:
					/* Let’s parse the date! */
					let date = try Self.dateFormatter.date(from: dateStr) ?! DecodingError.dataCorruptedError(in: container, debugDescription: "Unexpected date format")
					self = .date(date)
			}
		}
		
		public func encode(to encoder: Encoder) throws {
			let strValue: String
			switch self {
				case .none:           strValue = "normal"
				case .now:            strValue = "now"
				case .date(let date): strValue = Self.dateFormatter.string(from: date)
			}
			var container = encoder.singleValueContainer()
			try container.encode(strValue)
		}
		
	}
	
	public var name: String
	public var uid: Int?
	
	@EmptyIsNil
	public var email: Email?
	public var description: String?
	
	public var passwordNeverExpires: Bool?
	public var cannotChangePassword: Bool?
	/* I could’ve made a property wrapper but I got lazy for this one… */
	public var passwordLastChangeSynoTimestamp: Int?
	/* Note: The date will be valid when read in UTC…
	 * TODO: Apply UTC to current Locale transformation, maybe. */
	public var passwordLastChange: Date? {
		get {passwordLastChangeSynoTimestamp.flatMap{ Date(timeIntervalSince1970: TimeInterval($0 * 24 * 60 * 60)) }}
		set {passwordLastChangeSynoTimestamp = newValue.flatMap{ Int($0.timeIntervalSince1970 / (24 * 60 * 60)) }}
	}
	
	public var expiration: Expiration?
	
	internal func forPatching(properties: Set<CodingKeys>) -> SynologyUser {
		var ret = SynologyUser(name: name)
		ret.uid = uid
		for property in properties {
			switch property {
				case .uid, .name: (/*nop*/)
				case .email:                           ret.email                           = email
				case .description:                     ret.description                     = description
				case .expiration:                      ret.expiration                      = expiration
				case .passwordNeverExpires:            ret.passwordNeverExpires            = passwordNeverExpires
				case .cannotChangePassword:            ret.cannotChangePassword            = cannotChangePassword
				case .passwordLastChangeSynoTimestamp: ret.passwordLastChangeSynoTimestamp = passwordLastChangeSynoTimestamp
			}
		}
		return ret
	}
	
	public enum CodingKeys : String, CodingKey {
		case name, uid
		case email, description
		case passwordNeverExpires = "passwd_never_expire",
			  cannotChangePassword = "cannot_chg_passwd",
			  passwordLastChangeSynoTimestamp = "password_last_change"
		case expiration = "expired"
	}
	
}
