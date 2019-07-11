/*
 * VerifySignatureMiddleware.swift
 * opendirectory_officectlproxy
 *
 * Created by François Lamboley on 11/07/2019.
 */

import Foundation

import Crypto
import OfficeKit
import Vapor



class VerifySignatureMiddleware : Middleware {
	
	let secret: Data
	
	init(secret s: Data) {
		secret = s
	}
	
	func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
		let signatureHeaders = request.http.headers["Officectl-Signature"]
		guard let signatureHeader = signatureHeaders.first, signatureHeaders.count == 1 else {
			throw BasicValidationError("No or too many signature headers")
		}
		
		let split = signatureHeader.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
		guard split.count == 3 else {
			throw BasicValidationError("Incorrectly signed request (incorrect number of components in signature)")
		}
		let validityStartStr = split[0]
		let validityEndStr = split[1]
		guard let validityStart = TimeInterval(validityStartStr), let validityEnd = TimeInterval(validityEndStr) else {
			throw BasicValidationError("Incorrectly signed request (either start or end validity time are incorrect)")
		}
		
		let t = Date().timeIntervalSince1970
		guard validityStart <= t && t <= validityEnd else {
			throw BasicValidationError("Request is no longer or not yet valid")
		}
		
		guard let requestSignature = Data(base64Encoded: split[2]) else {
			throw BasicValidationError("Incorrectly signed request (signature is not valid base64)")
		}
		
		guard let body = request.http.body.data else {
			throw InternalError(message: "Cannot validate request with a streaming body")
		}
		
		let sepData = Data(":".utf8)
		let signedData = (
			Data(validityStartStr.utf8).base64EncodedData()      + sepData +
			Data(validityEndStr.utf8).base64EncodedData()        + sepData +
			Data(request.http.url.path.utf8).base64EncodedData() + sepData +
			body.base64EncodedData()
		)
		let computedSignature = try HMAC.SHA256.authenticate(signedData, key: secret)
		
		guard requestSignature == computedSignature else {
			throw BasicValidationError("Incorrectly signed request")
		}
		
		return try next.respond(to: request)
	}
	
}
