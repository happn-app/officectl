/*
 * ExternalServiceError.swift
 * OfficeKit
 *
 * Created by François Lamboley on 10/07/2019.
 */

import Foundation



struct ExternalServiceError : Decodable, Error {
	
	var domain: String?
	var code: Int
	var message: String?
	
}
