/*
 * GenericDirectoryUser+Utils.swift
 * officectl_odproxy
 *
 * Created by François Lamboley on 18/07/2019.
 */

import Foundation

import OfficeKit



extension GenericDirectoryUser {
	
	init(recordWrapper: ODRecordOKWrapper, odService: OpenDirectoryService) throws {
		self.init(userId: .native(.string(recordWrapper.userId.stringValue)))
		do {
			let json = try odService.exportableJSON(from: recordWrapper)
			guard case .object(let object) = json else {return}
			for (k, v) in object {
				self[k] = .set(v)
			}
		} catch {
			/*nop*/
		}
	}
	
}
