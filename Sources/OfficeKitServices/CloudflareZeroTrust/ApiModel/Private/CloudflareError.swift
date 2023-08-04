/*
 * CloudflareError.swift
 * CloudflareZeroTrustOffice
 *
 * Created by François Lamboley on 2023/07/28.
 */

import Foundation



struct CloudflareError : Sendable, Decodable {
	
	var code: Int
	var message: String
	
}
