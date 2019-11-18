/*
 * ApiResponse.swift
 * officectl
 *
 * Created by François Lamboley on 21/02/2019.
 */

import Foundation

import Vapor



enum ApiResponse<ObjectType : Encodable> : Encodable {
	
	case data(ObjectType)
	case error(ApiError)
	
	init(result: Result<ObjectType, Error>, environment: Environment) {
		switch result {
		case .success(let o): self = .data(o)
		case .failure(let e): self = .error(ApiError(error: e, environment: environment))
		}
	}
	
	init(error: Error, environment: Environment) {
		self = .error(ApiError(error: error, environment: environment))
	}
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: ApiResponse<ObjectType>.CodingKeys.self)
		switch self {
		case .data(let object):
			try container.encode(object, forKey: .data)
			
		case .error(let error):
			try container.encode(error, forKey: .error)
		}
	}
	
	private enum CodingKeys : String, CodingKey {
		case data
		case error
	}
	
}

extension ApiResponse : ResponseEncodable {
	
	func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
		let response = Response()
		do {
			try response.content.encode(self, as: .json)
			return request.eventLoop.makeSucceededFuture(response)
		} catch {
			return request.eventLoop.makeFailedFuture(error)
		}
		
//		let encoder = JSONEncoder()
//		encoder.dateEncodingStrategy = .iso8601
//		encoder.keyEncodingStrategy = .convertToSnakeCase
//		do    {return try req.eventLoop.makeSucceededFuture(req.response(encoder.encode(self), as: .json))}
//		catch {return req.eventLoop.makeFailedFuture(error)}
	}
	
}


extension Error {
	
	func asApiResponse(environment: Environment) -> ApiResponse<String> {
		return ApiResponse<String>.error(ApiError(error: self, environment: environment))
	}
	
}
