/*
 *  Config.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/11/15.
 */

import Foundation

import Logging
import UnwrapOrThrow



public enum GoogleOfficeConfig : Sendable {
	
	static public var logger: Logger? = Logger(label: "com.happn.officekit-services.google")
	
	/* Let’s use the config as a “globals container…” */
	static let dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = {
		return .custom{ decoder in
			let container = try decoder.singleValueContainer()
			let str = try container.decode(String.self)
			let formatter = ISO8601DateFormatter()
			formatter.formatOptions = formatter.formatOptions.union(.withFractionalSeconds)
			return try formatter.date(from: str) ?! DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(str)")
		}
	}()
	
}

typealias Conf = GoogleOfficeConfig
