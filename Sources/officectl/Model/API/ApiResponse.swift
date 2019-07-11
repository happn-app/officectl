/*
 * ApiResponse.swift
 * officectl
 *
 * Created by François Lamboley on 21/02/2019.
 */

import Foundation

import Vapor



enum ApiResponse<ObjectType : Encodable> : Encodable {
	
	case error(ApiError)
	case data(ObjectType)
	
	init(error: Error, environment: Environment) {
		self = .error(ApiError(error: error, environment: environment))
	}
	
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

extension ApiResponse : ResponseEncodable {
	
	func encode(for req: Request) throws -> Future<Response> {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		encoder.keyEncodingStrategy = .convertToSnakeCase
		return try req.future(req.response(encoder.encode(self), as: .json))
	}
	
}


extension Error {
	
	func asApiResponse(environment: Environment) -> ApiResponse<String> {
		return ApiResponse<String>.error(ApiError(error: self, environment: environment))
	}
	
}
