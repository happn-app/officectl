/*
 * SearchRequest.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/18.
 */

import Foundation



internal struct SearchRequest : Sendable, Encodable {
	
	var offset: Int?
	var limit: Int?
	
	var isAdmin: Bool = true
	
	var ids: [String]?
	var fullTextSearchWithAllTerms: String?
	
	private enum CodingKeys : String, CodingKey {
		
		case offset, limit
		case isAdmin = "is_admin"
		case ids, fullTextSearchWithAllTerms = "full_text_search_with_all_terms"
		
	}
	
}
