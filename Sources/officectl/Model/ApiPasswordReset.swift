/*
 * ApiPasswordReset.swift
 * officectl
 *
 * Created by François Lamboley on 15/04/2019.
 */

import Foundation

import OfficeKit



struct ApiPasswordReset : Codable {
	
	var userId: UserId
	
	var isExecuting: Bool
	var services: [ApiServicePasswordReset]
	
}
