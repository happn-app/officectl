/*
 * ApiError.swift
 * opendirectory_officectlproxy
 *
 * Created by François Lamboley on 11/07/2019.
 */

import Foundation



struct ApiError : Encodable, Error {
	
	var domain: String?
	var code: Int
	var message: String?
	
}
