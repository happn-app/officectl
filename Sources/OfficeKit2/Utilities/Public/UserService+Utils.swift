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
	
	/**
	 Returns the value for the property.
	 Always return either a `set` or `unsupported` property; never an `unset` one.
	 (I’m not sure we’ll keep the concept of an `unset` property…) */
	func valueForProperty(_ property: UserProperty, inUser user: UserType) -> RemoteProperty<AnyUserPropertyValue?> {
		guard supportedUserProperties.contains(property) else {
			return .unsupported
		}
		
		return .set(user.oU_valueForProperty(property))
	}
	
}
