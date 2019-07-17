/*
 * VerifySignatureMiddleware.swift
 * officectl_odproxy
 *
 * Created by François Lamboley on 11/07/2019.
 */

import Foundation

import Crypto
import OfficeKit
import Vapor



class VerifySignatureMiddleware : Middleware {
	
	typealias SignatureURLPathPrefixTransform = (from: String, to: String)
	
	let secret: Data
	let signatureURLPathPrefixTransform: SignatureURLPathPrefixTransform?
	
	init(secret s: Data, signatureURLPathPrefixTransform t: SignatureURLPathPrefixTransform?) {
		secret = s
		signatureURLPathPrefixTransform = t
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
		
		let body = request.http.body.data ?? Data()
		let requestURLPath = try transformURLPath(request.http.url.path)
		
		let sepData = Data(":".utf8)
		let signedData = (
			Data(validityStartStr.utf8).base64EncodedData() + sepData +
			Data(validityEndStr.utf8).base64EncodedData()   + sepData +
			Data(requestURLPath.utf8).base64EncodedData()   + sepData +
			body.base64EncodedData()
		)
		let computedSignature = try HMAC.SHA256.authenticate(signedData, key: secret)
		
		guard requestSignature == computedSignature else {
			throw BasicValidationError("Incorrectly signed request")
		}
		
		return try next.respond(to: request)
	}
	
	private func transformURLPath(_ path: String) throws -> String {
		guard let t = signatureURLPathPrefixTransform else {return path}
		guard let r = path.range(of: t.from), r.lowerBound == path.startIndex else {
			throw BasicValidationError("Cannot validate the signature because the path does not have the expected prefix.")
		}
		
		var ret = path
		ret.replaceSubrange(r, with: t.to)
		return ret
	}
	
}
