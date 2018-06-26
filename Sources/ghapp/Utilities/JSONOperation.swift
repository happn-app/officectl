/*
 * JSONOperation.swift
 * ghapp
 *
 * Created by François Lamboley on 25/06/2018.
 */

import Foundation

import URLRequestOperation



class JSONOperation<ObjectType : Decodable> : URLRequestOperation {
	
	var decodedObject: ObjectType?
	
	override func computeRetryInfo(sourceError error: Error?, completionHandler: @escaping (URLRequestOperation.RetryMode, URLRequest, Error?) -> Void) {
		guard error == nil, let fetchedData = fetchedData else {
			/* There is already an URL operation error. */
			super.computeRetryInfo(sourceError: error ?? NSError(domain: "com.happn.ghapp", code: 1, userInfo: [NSLocalizedDescriptionKey: "No data, unknown error"]), completionHandler: completionHandler)
			return
		}
		
		do {
			let decoder = JSONDecoder()
			decoder.keyDecodingStrategy = .convertFromSnakeCase
			decodedObject = try decoder.decode(ObjectType.self, from: fetchedData)
			completionHandler(.doNotRetry, currentURLRequest, nil)
		} catch {
			print("Cannot decode JSON \(fetchedData.reduce("", { $0 + String(format: "%02x", $1) }))", to: &stderrStream)
			completionHandler(.doNotRetry, currentURLRequest, error)
		}
	}
	
}
