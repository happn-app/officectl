/*
 * ApiResponse.swift
 * officectl_odproxy
 *
 * Created by François Lamboley on 11/07/2019.
 */

import Foundation

import Vapor



enum ApiResponse<ObjectType : Encodable> : Encodable {
	
	case data(ObjectType)
	case error(ApiError)
	
	init(error: Error) {
		self = .error(ApiError(error: error))
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


extension ApiResponse : ResponseEncodable, AsyncResponseEncodable {
	
	func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
		return request.eventLoop.makeSucceededFuture(()).flatMapThrowing{ try self.syncEncode(for: request) }
	}
	
	func encodeResponse(for request: Request) async throws -> Response {
		return try syncEncode(for: request)
	}
	
	/* Convenience, not part of the protocol. */
	func syncEncode(for req: Request) throws -> Response {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		
		var headers = HTTPHeaders()
		headers.replaceOrAdd(name: .contentType, value: HTTPMediaType.json.serialize())
		
		return try Response(headers: headers, body: Response.Body(data: encoder.encode(self)))
	}
	
}
