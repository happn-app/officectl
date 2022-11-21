/*
 * HappnBirthDateWrapper.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/20.
 */

import Foundation



@propertyWrapper
internal struct HappnBirthDateWrapper : Sendable, Hashable, Equatable, Codable {
	
	static let birthDateFormatter: DateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd"
		dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
		dateFormatter.locale = Locale(identifier: "en_US_POSIX")
		return dateFormatter
	}()
	
	var wrappedValue: Date?
	
	init(wrappedValue: Date?) {
		self.wrappedValue = wrappedValue
	}
	
	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		let dateStr = try container.decode(String.self)
		guard let d = Self.birthDateFormatter.date(from: dateStr) else {
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "cannot parse birth date")
		}
		self.wrappedValue = d
	}
	
	func encode(to encoder: Encoder) throws {
		guard let wrappedValue else {return}
		var container = encoder.singleValueContainer()
		try container.encode(Self.birthDateFormatter.string(from: wrappedValue))
	}
	
}


extension KeyedDecodingContainer {
	
	func decode(_ type: HappnBirthDateWrapper.Type, forKey key: Key) throws -> HappnBirthDateWrapper {
		return try decodeIfPresent(HappnBirthDateWrapper.self, forKey: key) ?? HappnBirthDateWrapper(wrappedValue: nil)
	}
	
}
