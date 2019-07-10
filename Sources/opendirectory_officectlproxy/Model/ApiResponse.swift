/*
 * ApiResponse.swift
 * opendirectory_officectlproxy
 *
 * Created by François Lamboley on 11/07/2019.
 */

import Foundation



enum ApiResponse<ObjectType : Encodable> : Encodable {
	
	case data(ObjectType)
	case error(ApiError)
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: ApiResponse<ObjectType>.CodingKeys.self)
		switch self {
		case .data(let object):
			try container.encode(object, forKey: .data)
			try container.encodeNil(forKey: .error)
			
		case .error(let error):
			try container.encode(error, forKey: .error)
			try container.encodeNil(forKey: .data)
		}
	}
	
	private enum CodingKeys : String, CodingKey {
		case data
		case error
	}
	
}
