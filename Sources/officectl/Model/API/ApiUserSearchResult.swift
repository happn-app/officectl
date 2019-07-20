/*
 * ApiUserSearchResult.swift
 * officectl
 *
 * Created by François Lamboley on 20/07/2019.
 */

import Foundation

import GenericJSON
import OfficeKit



struct ApiUserSearchResult : Encodable {
	
	var request: TaggedId
	var results: [String: ApiResponse<JSON?>]
	
}
