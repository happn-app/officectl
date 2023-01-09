/*
 * VerifySignatureMiddleware.swift
 * officectl-odproxy
 *
 * Created by François Lamboley on 2019/07/11.
 */

import Foundation

import Crypto
import OfficeKit2
import Vapor



class VerifySignatureMiddleware : AsyncMiddleware {
	
	struct SignatureURLPathPrefixTransform : Codable {
		
		var from: String
		var to: String
		
	}
	
	let secret: Data
	let signatureURLPathPrefixTransform: SignatureURLPathPrefixTransform?
	
	init(secret s: Data, signatureURLPathPrefixTransform t: SignatureURLPathPrefixTransform?) {
		secret = s
		signatureURLPathPrefixTransform = t
	}
	
	func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
		let signatureHeaders = request.headers["Officectl-Signature"]
		guard let signatureHeader = signatureHeaders.onlyElement else {
			throw Abort(.badRequest, reason: "No or too many signature headers")
		}
		
		let split = signatureHeader.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
		guard split.count == 3 else {
			throw Abort(.badRequest, reason: "Incorrectly signed request (incorrect number of components in signature)")
		}
		let validityStartStr = split[0]
		let validityEndStr = split[1]
		guard let validityStart = TimeInterval(validityStartStr), let validityEnd = TimeInterval(validityEndStr) else {
			throw Abort(.badRequest, reason: "Incorrectly signed request (either start or end validity time are incorrect)")
		}
		
		let t = Date().timeIntervalSince1970
		guard validityStart <= t && t <= validityEnd else {
			throw Abort(.badRequest, reason: "Request is no longer or not yet valid")
		}
		
		guard let requestSignature = Data(base64Encoded: split[2]) else {
			throw Abort(.badRequest, reason: "Incorrectly signed request (signature is not valid base64)")
		}
		
		var bodyBuffer = request.body.data
		let bodyBufferLength = bodyBuffer?.readableBytes ?? 0
		let body = bodyBuffer?.readBytes(length: bodyBufferLength).flatMap{ Data($0) } ?? Data()
		let requestURLPath = try transformURLPath(request.url.path)
		
		let sepData = Data(":".utf8)
		let signedData = (
			Data(validityStartStr.utf8).base64EncodedData() + sepData +
			Data(validityEndStr.utf8).base64EncodedData()   + sepData +
			Data(requestURLPath.utf8).base64EncodedData()   + sepData +
			body.base64EncodedData()
		)
		let computedSignature = Data(HMAC<SHA256>.authenticationCode(for: signedData, using: SymmetricKey(data: secret)))
		
		guard requestSignature == computedSignature else {
			throw Abort(.badRequest, reason: "Incorrectly signed request")
		}
		
		return try await next.respond(to: request)
	}
	
	private func transformURLPath(_ path: String) throws -> String {
		guard let t = signatureURLPathPrefixTransform else {return path}
		guard let r = path.range(of: t.from), r.lowerBound == path.startIndex else {
			throw Abort(.badRequest, reason: "Cannot validate the signature because the path does not have the expected prefix.")
		}
		
		var ret = path
		ret.replaceSubrange(r, with: t.to)
		return ret
	}
	
}
