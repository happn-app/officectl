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
	case failure(ApiError)
	
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
			self = .failure(try container.decode(ApiError.self, forKey: .error))
		}
	}
	
	enum CodingKeys : String, CodingKey {
		case data
		case error
		case success
	}
	
}
