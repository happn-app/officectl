/*
 * OfficeKitUser+ODUser.swift
 * officectl-odproxy
 *
 * Created by François Lamboley on 2023/01/11.
 */

import Foundation

import OfficeKit2
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
	
}
