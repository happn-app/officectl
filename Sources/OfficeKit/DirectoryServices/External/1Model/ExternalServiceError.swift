/*
 * ExternalServiceError.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/07/10.
 */

import Foundation



struct ExternalServiceError : Decodable, Error {
	
	var domain: String?
	var code: Int
	var message: String?
	
}
