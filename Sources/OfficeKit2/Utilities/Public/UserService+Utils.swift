/*
 * UserService+Utils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/12/10.
 * 
 */

import Foundation

import OfficeModelCore



public extension UserService {
	
	func taggedID(fromUserID userID: UserType.UserIDType) -> TaggedID {
		TaggedID(tag: id, id: string(fromUserID: userID))
	}
	
	func allLogicalTaggedIDs<OtherUserType : User>(fromOtherUser user: OtherUserType) throws -> Set<TaggedID> {
		let logicalUserID = try logicalUserID(fromUser: user)
		let allIDs = alternateIDs(fromUserID: logicalUserID)
		return Set([taggedID(fromUserID: allIDs.regular)] + allIDs.other.map{ taggedID(fromUserID: $0) })
	}
	
}
