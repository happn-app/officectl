/*
 * WebCertificateRenewController.swift
 * officectl
 *
 * Created by François Lamboley on 23/05/2019.
 */

import Foundation

import OfficeKit
import Vapor



class WebCertificateRenewController {
	
	func showLogin(_ req: Request) throws -> Future<View> {
		return try req.view().render("CertificateRenewLogin")
	}
	
	func renewCertificate(_ req: Request) throws -> Future<View> {
		let renewCertificateData = try req.content.syncDecode(RenewCertificateData.self)
		print(renewCertificateData)
		
		return try req.view().render("CertificateRenewLogin")
	}
	
	private struct RenewCertificateData : Decodable {
		
		var username: Email
		var password: String
		
	}
	
}
