/*
 * VerifySignatureMiddleware.swift
 * opendirectory_officectlproxy
 *
 * Created by François Lamboley on 11/07/2019.
 */

import Foundation

import Vapor



class VerifySignatureMiddleware : Middleware {
	
	func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
		let signatureHeaders = request.http.headers["Officectl-Signature"]
		guard let signatureHeader = signatureHeaders.first, signatureHeaders.count == 1 else {
			throw BasicValidationError("No or too many signature headers")
		}
		guard signatureHeader == "TODO" else {
			throw BasicValidationError("Incorrectly signed request")
		}
		
		return try next.respond(to: request)
	}
	
}
