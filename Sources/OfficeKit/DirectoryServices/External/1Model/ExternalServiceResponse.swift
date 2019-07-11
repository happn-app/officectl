/*
 * ExternalServiceResponse.swift
 * OfficeKit
 *
 * Created by François Lamboley on 10/07/2019.
 */

import Foundation



enum ExternalServiceResponse<ObjectType : Decodable> : Decodable {
	
	case data(ObjectType)
	case error(ExternalServiceError)
	
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		let object = try container.decodeIfPresent(ObjectType.self, forKey: .data)
		let error = try container.decodeIfPresent(ExternalServiceError.self, forKey: .error)
		
		switch (object, error) {
		case (nil,         let error?): self = .error(error)
		case (let object?, nil):        self = .data(object)
		case (nil, nil), (_?, _?):
			/* The error is not on the .data key precisely; it’s both on data and
			 * error… But I did not find a way to express that. */
			throw DecodingError.dataCorruptedError(forKey: .data, in: container, debugDescription: "Both data and error are nil or non-nil")
		}
	}
	
	func asResult() -> Result<ObjectType, ExternalServiceError> {
		switch self {
		case .data(let data):   return .success(data)
		case .error(let error): return .failure(error)
		}
	}
	
	func getData() throws -> ObjectType {
		switch self {
		case .data(let data):   return data
		case .error(let error): throw error
		}
	}
	
	private enum CodingKeys : String, CodingKey {
		case data
		case error
	}
	
}
