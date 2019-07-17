/*
 * ApiUser.swift
 * officectl
 *
 * Created by François Lamboley on 01/03/2019.
 */

import Foundation

import GenericJSON
import OfficeKit



struct ApiUser : Encodable {
	
	var requestedUserId: TaggedId
	
	var serviceUsers: [String: ApiResponse<JSON?>]
	
}
