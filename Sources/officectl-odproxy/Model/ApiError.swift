/*
 * ApiError.swift
 * officectl_odproxy
 *
 * Created by François Lamboley on 2019/07/11.
 */

import Foundation



struct ApiError : Encodable, Error {
	
	var domain: String?
	var code: Int
	var message: String?
	
	init(error: Error) {
		domain = nil
		code = 1
		message = error.legibleLocalizedDescription
	}
	
}
