/*
 * ApiResponse.swift
 * officectl
 *
 * Created by François Lamboley on 21/02/2019.
 */

import Foundation



enum ApiResponse<ObjectType : Encodable> : Encodable {
	
	case error(ApiError)
	case data(ObjectType)
	
	func encode(to encoder: Encoder) throws {
		switch self {
		case .data(let object):
			var container = encoder.container(keyedBy: ApiResponse<ObjectType>.CodingKeys.self)
			try container.encode(object, forKey: .data)
			try container.encodeNil(forKey: .error)
			
		case .error(let error):
			var container = encoder.container(keyedBy: ApiResponse<ObjectType>.CodingKeys.self)
			try container.encode(error, forKey: .error)
			try container.encodeNil(forKey: .data)
		}
	}
	
	private enum CodingKeys : String, CodingKey {
		case data
		case error
	}
	
}


extension Error {
	
	var asApiResponse: ApiResponse<String> {
		return ApiResponse<String>.error(ApiError(error: self))
	}
	
}
