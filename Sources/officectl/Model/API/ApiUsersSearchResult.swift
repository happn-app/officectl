/*
 * ApiUsersSearchResult.swift
 * officectl
 *
 * Created by François Lamboley on 20/07/2019.
 */

import Foundation

import GenericJSON
import OfficeKit



struct ApiUsersSearchResult : Encodable {
	
	var request: String
	var results: [[String: JSON?]]
	var errorsByServiceId: [String: ApiError]
	
}
