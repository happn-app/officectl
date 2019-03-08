/*
 * AuthenticatedJSONOperation.swift
 * officectl
 *
 * Created by François Lamboley on 25/06/2018.
 */

import Foundation

import AsyncOperationResult
import URLRequestOperation



public class AuthenticatedJSONOperation<ObjectType : Decodable> : URLRequestOperation, HasResult {
	
	public typealias ResultType = ObjectType
	
	public static var defaultDecoder: JSONDecoder {
		let r = JSONDecoder()
		r.keyDecodingStrategy = .convertFromSnakeCase
		return r
	}
	
	public typealias Authenticator = (_ request: URLRequest, _ handler: @escaping (AsyncOperationResult<URLRequest>, Any?) -> Void) -> Void
	public let authenticator: Authenticator?
	
	public let decoder: JSONDecoder
	
	public var fetchedObject: ObjectType?
	public func resultOrThrow() throws -> ObjectType {
		switch (fetchedObject, finalError) {
		case (nil,               nil):              throw OperationIsNotFinishedError()
		case (.some(let object), _):                return object
		case (_,                 .some(let error)): throw error
		}
	}
	
	public convenience init(request: URLRequest, authenticator a: Authenticator?, decoder: JSONDecoder = AuthenticatedJSONOperation<ObjectType>.defaultDecoder) {
		self.init(config: URLRequestOperation.Config(request: request, session: nil), authenticator: a, decoder: decoder)
	}
	
	public convenience init(url: URL, authenticator a: Authenticator?, decoder: JSONDecoder = AuthenticatedJSONOperation<ObjectType>.defaultDecoder) {
		self.init(request: URLRequest(url: url), authenticator: a, decoder: decoder)
	}
	
	public init(config c: URLRequestOperation.Config, authenticator a: Authenticator?, decoder d: JSONDecoder = AuthenticatedJSONOperation<ObjectType>.defaultDecoder) {
		decoder = d
		authenticator = a
		super.init(config: c)
	}
	
	public override func processURLRequestForRunning(_ originalRequest: URLRequest, handler: @escaping (AsyncOperationResult<URLRequest>) -> Void) {
		guard let authenticator = authenticator else {
			handler(.success(originalRequest))
			return
		}
		
		authenticator(originalRequest, { r, _ in handler(r) })
	}
	
	public override func computeRetryInfo(sourceError error: Error?, completionHandler: @escaping (URLRequestOperation.RetryMode, URLRequest, Error?) -> Void) {
		guard error == nil, let fetchedData = fetchedData else {
			/* There is already an URL operation error. */
			super.computeRetryInfo(sourceError: error ?? NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "No data, unknown error"]), completionHandler: completionHandler)
			return
		}
		
		do {
			fetchedObject = try decoder.decode(ObjectType.self, from: fetchedData)
			completionHandler(.doNotRetry, currentURLRequest, nil)
		} catch {
			print("Cannot decode JSON; error \(error) \(fetchedData.reduce("", { $0 + String(format: "%02x", $1) }))", to: &stderrStream)
			completionHandler(.doNotRetry, currentURLRequest, error)
		}
	}
	
}
