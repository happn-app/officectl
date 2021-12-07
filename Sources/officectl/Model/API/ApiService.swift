/*
 * ApiService.swift
 * officectl
 *
 * Created by François Lamboley on 10/05/2019.
 */

import Foundation



struct ApiService : Codable {
	
	var providerId: String
	
	var serviceId: String
	var serviceFullName: String
	
	var isHelperService: Bool
	
}
