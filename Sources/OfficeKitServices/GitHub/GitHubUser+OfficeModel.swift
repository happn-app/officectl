/*
 * GitHubUser+OfficeModel.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/28.
 */

import Foundation

import Email

import OfficeKit2



extension GitHubUser : User {
	
	public typealias UserIDType = String
	/**
	 We chose the id of the user for the persistent id, not the node ID.
	 I don’t know which is best tbh.
	 Probably the node ID… */
	public typealias PersistentUserIDType = Int
	
	public init(oU_id userID: String) {
		self.login = userID
	}
	
	public var oU_id: String {
		return login
	}
	
	public var oU_persistentID: Int? {
		return id
	}
	
	/** We do not support the suspended state (not GitHub Enterprise). */
	public var oU_isSuspended: Bool? {
		return false
	}
	
	public var oU_firstName: String? {
		/* We could try and be smart and split the name in an inferred first name + last name, but the reality of names is so that it’d be often incorrect.
		 * Let’s accept that and return the full name in the first name AND the last name.
		 * Who cares. */
		return name
	}
	
	public var oU_lastName: String? {
		/* See first name. */
		return name
	}
	
	public var oU_nickname: String? {
		return login
	}
	
	public var oU_emails: [Email]? {
		/* The email we get from GitHub (if any) has no value from an Office pov.
		 * This is not a GitHub Enterprise office, just a GitHub office:
		 *  the emails we get are private and unknown to the office. */
		return []
	}
	
	public func oU_valueForNonStandardProperty(_ property: String) -> Sendable? {
		switch UserProperty(rawValue: property) {
				/* We do not support any non-standard properties for now. */
			default: return nil
		}
	}
	
	public mutating func oU_setValue<V>(_ newValue: V?, forProperty property: UserProperty, allowIDChange: Bool, convertMismatchingTypes: Bool) -> Bool where V : Sendable {
		Conf.logger?.info("Cannot change any property of a GitHub User (not GitHub Enterprise; only the user can change his profile).")
		return false
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	internal static var propertyToKeys: [UserProperty: [GitHubUser.CodingKeys]] {
		[
			/* Standard. */
			.id: [.login],
			.persistentID: [.id],
			.isSuspended: [],
			.emails: [],
			.firstName: [.name],
			.lastName: [.name],
			.nickname: [.login],
			.password: []
			/* Other. */
		]
	}
	
	internal static func keysFromProperties(_ properties: Set<UserProperty>?) -> Set<GitHubUser.CodingKeys> {
		let properties = properties ?? Set(UserProperty.standardProperties + [])
		let keys = properties
			.compactMap{ propertyToKeys[$0] }
			.flatMap{ $0 }
		return Set(keys)
	}
	
	internal static func validFieldsParameter(from keys: Set<CodingKeys>) -> String {
		return (keys + [.id, .type]).map{ $0.stringValue }.joined(separator: ",")
	}
	
}
