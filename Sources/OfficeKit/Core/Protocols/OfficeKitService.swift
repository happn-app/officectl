/*
 * OfficeKitService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/06/2019.
 */

import Foundation



public protocol OfficeKitService {
	
	static var id: String {get}
	
	var serviceId: String {get}
	var serviceName: String {get}
	
}
