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
		
		if let error = try container.decodeIfPresent(ExternalServiceError.self, forKey: .error) {
			self = .error(error)
		} else {
			self = .data(try container.decode(ObjectType.self, forKey: .data))
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
