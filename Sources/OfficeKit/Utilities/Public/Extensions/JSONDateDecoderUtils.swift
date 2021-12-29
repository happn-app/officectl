/*
 * JSONDateDecoderUtils.swift
 * officectl
 *
 * Created by François Lamboley on 2018/06/26.
 */

import Foundation



public extension Formatter {
	
#if !os(Linux)
	static let iso8601: ISO8601DateFormatter = {
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		return formatter
	}()
#else
	static let iso8601: DateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.calendar = Calendar(identifier: .iso8601)
		dateFormatter.locale = Locale(identifier: "en_US_POSIX")
		dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
		dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
		return dateFormatter
	}()
#endif
	
}

public extension JSONDecoder.DateDecodingStrategy {
	
	static let customISO8601 = custom{ decoder throws -> Date in
		let container = try decoder.singleValueContainer()
		let string = try container.decode(String.self)
		guard let date = Formatter.iso8601.date(from: string) else {
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
		}
		return date
	}
	
}

public extension JSONEncoder.DateEncodingStrategy {
	
	static let customISO8601 = custom{ date, encoder throws in
		var container = encoder.singleValueContainer()
		try container.encode(Formatter.iso8601.string(from: date))
	}
	
}
