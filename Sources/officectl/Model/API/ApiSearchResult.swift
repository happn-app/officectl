/*
 * ApiUsersSearchResult.swift
 * officectl
 *
 * Created by François Lamboley on 20/07/2019.
 */

import Foundation

import GenericJSON
import OfficeKit



struct ApiSearchResult<RequestType : Encodable, ResultType : Encodable> : Encodable {
	
	var request: RequestType
	var errorsByServiceId: [String: [ApiError]]
	
	var result: ResultType
	
}

typealias ApiUserSearchResult = ApiSearchResult<TaggedId, ApiUser>
typealias ApiUsersSearchResult = ApiSearchResult<String, [ApiUser]>
