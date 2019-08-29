/*
 * HappnApiResult.swift
 * OfficeKit
 *
 * Created by François Lamboley on 29/08/2019.
 */

import Foundation



internal struct HappnApiResult<DataType : Codable> : Codable {
	
	var success: Bool
	var data: DataType?
	
	var status: Int
	var error: String?
	var error_code: Int
	
}
