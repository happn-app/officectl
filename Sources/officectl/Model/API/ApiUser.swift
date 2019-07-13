/*
 * ApiUser.swift
 * officectl
 *
 * Created by François Lamboley on 01/03/2019.
 */

import Foundation

import OfficeKit



struct ApiUser : Codable {
	
	var userId: TaggedId
	var persistentId: String?
	
	var emails: [Email]
	
	var firstName: String?
	var lastName: String?
	var nickname: String?
	
	var password: String?
	
}
