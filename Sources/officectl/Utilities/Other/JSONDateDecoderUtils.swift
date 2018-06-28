/*
 * JSONDateDecoderUtils.swift
 * officectl
 *
 * Created by François Lamboley on 26/06/2018.
 */

import Foundation



extension Formatter {
	
	static let iso8601: ISO8601DateFormatter = {
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		return formatter
	}()
	
}

extension JSONDecoder.DateDecodingStrategy {
	
	static let customISO8601 = custom{ decoder throws -> Date in
		let container = try decoder.singleValueContainer()
		let string = try container.decode(String.self)
		if let date = Formatter.iso8601.date(from: string) {
			return date
		}
		throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
	}
	
}

extension JSONEncoder.DateEncodingStrategy {
	
	static let customISO8601 = custom{ date, encoder throws in
		var container = encoder.singleValueContainer()
		try container.encode(Formatter.iso8601.string(from: date))
	}
	
}
