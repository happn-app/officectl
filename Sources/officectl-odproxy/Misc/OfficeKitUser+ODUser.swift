/*
 * OfficeKitUser+ODUser.swift
 * officectl-odproxy
 *
 * Created by François Lamboley on 2023/01/11.
 */

import Foundation

import OfficeModelCore
import UnwrapOrThrow

import OfficeKit
import OfficeKitOffice
import OpenDirectoryOffice



extension OfficeKitUser {
	
	init(odUser: OpenDirectoryUser, odService: OpenDirectoryService) throws {
		self.init(
			underlyingUser: UserAndServiceFrom(user: odUser, service: odService)!,
			nonStandardProperties: [:],
			opaqueUserInfo: try JSONEncoder().encode(odUser.properties)
		)
	}
	
	func odUser(odServiceID: Tag) throws -> OpenDirectoryUser {
		guard id.tag == odServiceID, let opaqueUserInfo else {
			throw InvalidUserError()
		}
		
		let persistentID: UUID?
		if let oU_persistentID {
			guard oU_persistentID.tag == odServiceID else {
				throw InvalidUserError()
			}
			persistentID = try UUID(uuidString: oU_persistentID.id) ?! InvalidUserError()
		} else {
			persistentID = nil
		}
		
#warning("TODO: Basic validation that set are properly done?")
		let properties = try JSONDecoder().decode([String: OpenDirectoryAttributeValue].self, from: opaqueUserInfo)
		var ret = OpenDirectoryUser(id: id.id, properties: properties)
		_ = ret.oU_setValue(persistentID, forProperty: .persistentID, convertMismatchingTypes: true)
		_ = ret.oU_setValue(isSuspended,  forProperty: .isSuspended,  convertMismatchingTypes: true)
		_ = ret.oU_setValue(firstName,    forProperty: .firstName,    convertMismatchingTypes: true)
		_ = ret.oU_setValue(lastName,     forProperty: .lastName,     convertMismatchingTypes: true)
		_ = ret.oU_setValue(nickname,     forProperty: .nickname,     convertMismatchingTypes: true)
		_ = ret.oU_setValue(emails,       forProperty: .emails,       convertMismatchingTypes: true)
		for (p, v) in nonStandardProperties {
			_ = ret.oU_setValue(v, forProperty: UserProperty(rawValue: p), convertMismatchingTypes: true)
		}
		
		return ret
	}
	
}
