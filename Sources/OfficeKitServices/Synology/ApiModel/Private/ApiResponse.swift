/*
 * ApiResponse.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation



struct Empty : Decodable {}

enum ApiResponse<Element : Sendable & Decodable> : Sendable, Decodable {
	
	case success(Element)
	case failure(SynologyApiError)
	
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		let success = try container.decode(Bool.self, forKey: .success)
		if success {
			if Element.self == Empty.self {
				guard !container.allKeys.contains(.data) else {
					throw DecodingError.dataCorruptedError(forKey: .data, in: container, debugDescription: "For an ApiResponse with an Empty element, the data key should not exist.")
				}
				self = .success(Empty() as! Element)
			} else {
				self = .success(try container.decode(Element.self, forKey: .data))
			}
		} else {
			self = .failure(try container.decode(SynologyApiError.self, forKey: .error))
		}
	}
	
	func get(apiErrorCodeToError: [Int: Error] = [:]) throws -> Element {
		return try get(apiErrorToError: { err in
			return apiErrorCodeToError[err.code] ?? Err.apiUnknownError(err)
		})
	}
	
	func get(apiErrorToError: @Sendable (SynologyApiError) -> Error) throws -> Element {
		switch self {
			case .success(let elt): return elt
			case .failure(let err): throw apiErrorToError(err)
		}
	}
	
	enum CodingKeys : String, CodingKey {
		case data
		case error
		case success
	}
	
}
