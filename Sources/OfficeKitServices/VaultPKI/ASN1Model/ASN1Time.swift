/*
 * ASN1Time.swift
 * VaultPKIOffice
 *
 * Created by François Lamboley on 2023/03/11.
 */

import Foundation

import SwiftASN1



/* From swift-certificates (internal struct, cannot be used). */
/*
 * Time ::= CHOICE {
 *      utcTime        UTCTime,
 *      generalTime    GeneralizedTime }
 */
enum ASN1Time : DERParseable, DERSerializable, Hashable, Sendable {
	
	case utcTime(UTCTime)
	case generalTime(GeneralizedTime)
	
	init(derEncoded rootNode: ASN1Node) throws {
		switch rootNode.identifier {
			case GeneralizedTime.defaultIdentifier: self = .generalTime(try GeneralizedTime(derEncoded: rootNode))
			case UTCTime.defaultIdentifier:         self = .utcTime(try UTCTime(derEncoded: rootNode))
			default:
				throw ASN1Error.unexpectedFieldType(rootNode.identifier)
		}
	}
	
	func serialize(into coder: inout DER.Serializer) throws {
		switch self {
			case .utcTime(let utcTime):             try coder.serialize(utcTime)
			case .generalTime(let generalizedTime): try coder.serialize(generalizedTime)
		}
	}
	
	static func makeTime(from date: Date) throws -> ASN1Time {
		let components = gregorianCalendar.dateComponents(in: utcTimeZone, from: date)
		
		/* The rule is if the year is outside the range 1950-2049 inclusive, we should encode it as a generalized time.
		 * Otherwise, use a UTCTime.
		 * These force-unwraps are safe: all the components are returned by the above call. */
		if (1950..<2050).contains(components.year!) {
			let utcTime = try UTCTime(
				year: components.year!,
				month: components.month!,
				day: components.day!,
				hours: components.hour!,
				minutes: components.minute!,
				seconds: components.second!
			)
			
			return .utcTime(utcTime)
		} else {
			let generalizedTime = try GeneralizedTime(
				year: components.year!,
				month: components.month!,
				day: components.day!,
				hours: components.hour!,
				minutes: components.minute!,
				seconds: components.second!,
				fractionalSeconds: 0.0
			)
			
			return .generalTime(generalizedTime)
		}
	}
	
}


extension Date {
	
	init?(_ time: ASN1Time) {
		let maybeDate: Date?
		
		switch time {
			case .utcTime(let utcTime):             maybeDate = Date(utcTime)
			case .generalTime(let generalizedTime): maybeDate = Date(generalizedTime)
		}
		
		guard let date = maybeDate else {
			return nil
		}
		
		self = date
	}
	
	init?(_ utcTime: UTCTime) {
		let components = DateComponents(
			calendar: gregorianCalendar,
			timeZone: utcTimeZone,
			year: utcTime.year,
			month: utcTime.month,
			day: utcTime.day,
			hour: utcTime.hours,
			minute: utcTime.minutes,
			second: utcTime.seconds
		)
		guard let date = components.date else {
			return nil
		}
		self = date
	}
	
	init?(_ generalizedTime: GeneralizedTime) {
		let components = DateComponents(
			calendar: gregorianCalendar,
			timeZone: utcTimeZone,
			year: generalizedTime.year,
			month: generalizedTime.month,
			day: generalizedTime.day,
			hour: generalizedTime.hours,
			minute: generalizedTime.minutes,
			second: generalizedTime.seconds
		)
		guard let date = components.date else {
			return nil
		}
		self = date
	}
	
}


let gregorianCalendar = Calendar(identifier: .gregorian)
let utcTimeZone = TimeZone(identifier: "UTC")!
