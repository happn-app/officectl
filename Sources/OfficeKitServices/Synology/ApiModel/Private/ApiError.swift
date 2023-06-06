/*
 * ApiError.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation



struct ApiError : Decodable {
	
	var code: Int
	
	enum CodingKeys: CodingKey {
		case code
	}
	
}
