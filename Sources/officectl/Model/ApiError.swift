/*
 * ApiError.swift
 * officectl
 *
 * Created by François Lamboley on 21/02/2019.
 */

import Foundation



struct ApiError : Codable {
	
	var code: Int
	var domain: String
	var message: String
	
	init(code c: Int, domain d: String, message m: String) {
		code = c
		domain = d
		message = m
	}
	
	init(error: Error) {
		code = (error as NSError).code
		domain = (error as NSError).domain
		message = error.localizedDescription
	}
	
}
