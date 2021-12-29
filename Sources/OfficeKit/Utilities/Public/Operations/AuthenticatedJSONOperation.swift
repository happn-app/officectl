/*
 * AuthenticatedJSONOperation.swift
 * officectl
 *
 * Created by François Lamboley on 2018/06/25.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import HasResult
import URLRequestOperation



//public class AuthenticatedJSONOperation<ObjectType : Decodable> : URLRequestOperationWithRetryRecoveryHandler, HasResult {
//
//	public typealias ResultType = ObjectType
//
//	public static var defaultDecoder: JSONDecoder {
//		let r = JSONDecoder()
//		r.keyDecodingStrategy = .convertFromSnakeCase
//		return r
//	}
//
//	public typealias Authenticator = (_ request: URLRequest, _ handler: @escaping (Result<URLRequest, Error>, Any?) -> Void) -> Void
//	public let authenticator: Authenticator?
//
//	public let decoder: JSONDecoder
//
//	public var fetchedObject: ObjectType?
//	public var result: Result<ObjectType, Error> {
//		switch (fetchedObject, finalError) {
//			case (nil,               nil):              return .failure(OperationIsNotFinishedError())
//			case (.some(let object), _):                return .success(object)
//			case (_,                 .some(let error)): return .failure(error)
//		}
//	}
//
//	public convenience init(request: URLRequest, authenticator a: Authenticator?, decoder: JSONDecoder = AuthenticatedJSONOperation<ObjectType>.defaultDecoder, retryInfoRecoveryHandler h: ComputeRetryInfoRecoverHandlerType? = nil) {
//		self.init(config: URLRequestOperation.Config(request: request, session: nil, maximumNumberOfRetries: 1, acceptableStatusCodes: nil, acceptableContentTypes: ["application/json"]), authenticator: a, decoder: decoder, retryInfoRecoveryHandler: h)
//	}
//
//	public convenience init(url: URL, authenticator a: Authenticator?, decoder: JSONDecoder = AuthenticatedJSONOperation<ObjectType>.defaultDecoder, retryInfoRecoveryHandler h: ComputeRetryInfoRecoverHandlerType? = nil) {
//		self.init(request: URLRequest(url: url), authenticator: a, decoder: decoder, retryInfoRecoveryHandler: h)
//	}
//
//	public init(config c: URLRequestOperation.Config, authenticator a: Authenticator?, decoder d: JSONDecoder = AuthenticatedJSONOperation<ObjectType>.defaultDecoder, retryInfoRecoveryHandler h: ComputeRetryInfoRecoverHandlerType? = nil) {
//		decoder = d
//		authenticator = a
//		super.init(config: c, retryInfoRecoveryHandler: h)
//	}
//
//	public override func processURLRequestForRunning(_ originalRequest: URLRequest, handler: @escaping (AsyncOperationResult<URLRequest>) -> Void) {
//		guard let authenticator = authenticator else {
//			handler(.success(originalRequest))
//			return
//		}
//
//		authenticator(originalRequest, { r, _ in handler(r.asyncOperationResult) })
//	}
//
//	public override func computeRetryInfo(sourceError error: Error?, completionHandler: @escaping (URLRequestOperation.RetryMode, URLRequest, Error?) -> Void) {
//		guard error == nil, let fetchedData = fetchedData else {
//			/* There is already an URL operation error. */
//			super.computeRetryInfo(sourceError: error ?? NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Nil data, unknown error"]), completionHandler: completionHandler)
//			return
//		}
//
//		do {
//			if let statusCode = statusCode, 200..<300 ~= statusCode {
//				fetchedObject = try decoder.decode(ObjectType.self, from: fetchedData)
//			} else {
//				let fetchedDataStr = String(data: fetchedData, encoding: .utf8) ?? (fetchedData.reduce("HexData<", { $0 + String(format: "%02x", $1) }) + ">")
//				throw InvalidArgumentError(message: "Invalid status code \(statusCode as Any? ?? "<nil>"). Data from request is: \(fetchedDataStr)")
//			}
//			completionHandler(.doNotRetry, currentURLRequest, nil)
//		} catch {
//			let completionHandler2 = { (retryMode: URLRequestOperation.RetryMode, request: URLRequest, error: Error?) -> Void in
//				if case .doNotRetry = retryMode, let error = error {
//					OfficeKitConfig.logger?.info("Network error or invalid JSON. Error \(error), data \(fetchedData.reduce("", { $0 + String(format: "%02x", $1) }))")
//				}
//				completionHandler(retryMode, request, error)
//			}
//			if let h = retryInfoRecoveryHandler {
//				h(self, error, completionHandler2)
//			} else {
//				completionHandler2(.doNotRetry, currentURLRequest, error)
//			}
//		}
//	}
//
//}
