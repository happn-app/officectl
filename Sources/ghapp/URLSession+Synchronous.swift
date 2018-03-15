/*
 * URLSession+Synchronous.swift
 * ghapp
 *
 * Created by François Lamboley on 2/6/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



extension URLSession {
	
	func synchronousDataTask(with request: URLRequest) throws -> (data: Data?, response: URLResponse?) {
		let semaphore = DispatchSemaphore(value: 0)
		
		var responseData: Data?
		var theResponse: URLResponse?
		var theError: Error?
		
		dataTask(with: request) { data, response, error in
			responseData = data
			theResponse = response
			theError = error
			
			semaphore.signal()
		}.resume()
		
		_ = semaphore.wait(timeout: .distantFuture)
		
		if let error = theError {
			throw error
		}
		
//		print("request: \(request.httpBody?.base64EncodedString())")
//		print("data: \(responseData?.base64EncodedString())")
		
		return (data: responseData, response: theResponse)
	}
	
}
