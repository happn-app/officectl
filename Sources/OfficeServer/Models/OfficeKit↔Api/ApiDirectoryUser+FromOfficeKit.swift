/*
 * ApiDirectoryUser+FromOfficeKit.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/19.
 */

import Foundation

import GenericJSON
import Logging

import OfficeKit
import OfficeModel



extension ApiDirectoryUser {
	
	init(userAndService: any UserAndService, logger: Logger? = nil) {
		self.init(
			serviceID: userAndService.serviceID,
			userID: userAndService.taggedID.id,
			persistentID: userAndService.taggedPersistentID?.id,
			isSuspended: userAndService.user.oU_isSuspended,
			firstName: userAndService.user.oU_firstName,
			lastName: userAndService.user.oU_lastName,
			nickname: userAndService.user.oU_nickname,
			emails: userAndService.user.oU_emails,
			nonStandardProperties: Dictionary(uniqueKeysWithValues: userAndService.user.oU_nonStandardProperties.compactMap{ property in
				guard let v = userAndService.user.oU_valueForNonStandardProperty(property) as? Encodable else {
					return (property, .null)
				}
				guard let json = try? JSON(encodable: v) else {
					logger?.warning("Got non-encodable value for custom property.", metadata: [LMK.property: "\(property)"])
					return nil
				}
				return (property, json)
			})
		)
	}
	
}
