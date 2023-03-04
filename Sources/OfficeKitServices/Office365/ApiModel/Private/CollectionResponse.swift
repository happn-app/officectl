/*
 * CollectionResponse.swift
 * Office365Office
 *
 * Created by François Lamboley on 2023/03/04.
 */

import Foundation



struct CollectionResponse<Element : Sendable & Decodable> : Sendable, Decodable {
	
	var count: Int?
	var nextLink: URL?
	
	var value: [Element]
	
	enum CodingKeys : String, CodingKey {
		case count    = "@odata.count"
		case nextLink = "@odata.nextLink"
		
		case value
	}
	
}
