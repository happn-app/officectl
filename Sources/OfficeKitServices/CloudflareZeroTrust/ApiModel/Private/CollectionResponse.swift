/*
 * CollectionResponse.swift
 * CloudflareZeroTrustOffice
 *
 * Created by François Lamboley on 2023/07/28.
 */

import Foundation



struct CollectionResponse<Element : Sendable & Decodable> : Sendable, Decodable {
	
	var result: [Element]
	var resultInfo: CollectionResponseInfo
	
	var success: Bool
	var errors: [CloudflareError]
	var messages: [CloudflareMessage]
	
	enum CodingKeys : String, CodingKey {
		case result
		case resultInfo = "result_info"
		
		case success
		case errors
		case messages
	}
	
}


struct CollectionResponseInfo : Sendable, Decodable {
	
	var page: Int
	var perPage: Int
	var count: Int
	var totalCount: Int
	
	enum CodingKeys : String, CodingKey {
		case page
		case perPage = "per_page"
		case count
		case totalCount = "total_count"
	}
	
}
