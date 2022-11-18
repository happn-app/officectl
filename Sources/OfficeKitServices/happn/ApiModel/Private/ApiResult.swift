/*
 * ApiResult.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/18.
 */

import Foundation



internal struct ApiResult<DataType : Sendable & Decodable> : Sendable, Decodable {
	
	var success: Bool
	var data: DataType?
	
	var status: Int
	var error: String?
	var errorCode: Int
	
	private enum CodingKeys : String, CodingKey {
		
		case success, data
		case status, error, errorCode = "error_code"
		
	}
	
}
