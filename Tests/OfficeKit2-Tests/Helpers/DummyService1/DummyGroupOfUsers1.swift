/*
 * DummyGroupOfUsers.swift
 * OfficeKitTests
 *
 * Created by François Lamboley on 2022/10/25.
 */

import Foundation

import Email

import OfficeKit2



struct DummyGroupOfUsers1 : GroupOfUsers {
	
	typealias GroupOfUsersIDType = Never
	typealias PersistentGroupOfUsersIDType = Never
	
	var oGOU_id: Never
	var oGOU_persistentID: Never?
	
	var oGOU_emails: [Email]
	var oGOU_name: String?
	var oGOU_description: String?
	
}
