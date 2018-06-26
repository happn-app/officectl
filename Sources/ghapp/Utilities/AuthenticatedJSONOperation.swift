/*
 * AuthenticatedJSONOperation.swift
 * ghapp
 *
 * Created by François Lamboley on 25/06/2018.
 */

import Foundation

import AsyncOperationResult
import URLRequestOperation



class AuthenticatedJSONOperation<ObjectType : Decodable> : URLRequestOperation {
	
	struct AuthConfig {
		
		static var defaultDecoder: JSONDecoder {
			let r = JSONDecoder()
			r.keyDecodingStrategy = .convertFromSnakeCase
			return r
		}
		
		typealias Authenticator = (_ request: URLRequest, _ handler: @escaping (AsyncOperationResult<URLRequest>, Any?) -> Void) -> Void
		let authenticator: Authenticator?
		
		let decoder: JSONDecoder
		
		init(authenticator a: Authenticator? = nil, decoder d: JSONDecoder = AuthConfig.defaultDecoder) {
			authenticator = a
			decoder = d
		}
		
	}
	
	let authConfig: AuthConfig
	
	var decodedObject: ObjectType?
	
	convenience init(request: URLRequest, authenticator a: AuthConfig.Authenticator?) {
		self.init(config: URLRequestOperation.Config(request: request, session: nil), authenticator: a)
	}
	
	convenience init(url: URL, authenticator a: AuthConfig.Authenticator?) {
		self.init(request: URLRequest(url: url), authenticator: a)
	}
	
	convenience init(url: URL, authConfig c: AuthConfig) {
		self.init(config: URLRequestOperation.Config(request: URLRequest(url: url), session: nil), authConfig: c)
	}
	
	convenience init(config c: URLRequestOperation.Config, authenticator a: AuthConfig.Authenticator?) {
		self.init(config: c, authConfig: AuthConfig(authenticator: a))
	}
	
	init(config c: URLRequestOperation.Config, authConfig ac: AuthConfig) {
		authConfig = ac
		super.init(config: c)
	}
	
	override func processURLRequestForRunning(_ originalRequest: URLRequest, handler: @escaping (AsyncOperationResult<URLRequest>) -> Void) {
		guard let authenticator = authConfig.authenticator else {
			handler(.success(originalRequest))
			return
		}
		
		authenticator(originalRequest, { r, _ in handler(r) })
	}
	
	override func computeRetryInfo(sourceError error: Error?, completionHandler: @escaping (URLRequestOperation.RetryMode, URLRequest, Error?) -> Void) {
		guard error == nil, let fetchedData = fetchedData else {
			/* There is already an URL operation error. */
			super.computeRetryInfo(sourceError: error ?? NSError(domain: "com.happn.ghapp", code: 1, userInfo: [NSLocalizedDescriptionKey: "No data, unknown error"]), completionHandler: completionHandler)
			return
		}
		
		do {
			decodedObject = try authConfig.decoder.decode(ObjectType.self, from: fetchedData)
			completionHandler(.doNotRetry, currentURLRequest, nil)
		} catch {
			print("Cannot decode JSON; error \(error) \(fetchedData.reduce("", { $0 + String(format: "%02x", $1) }))", to: &stderrStream)
			completionHandler(.doNotRetry, currentURLRequest, error)
		}
	}
	
}
