/*
 * URLRequestOperationWithRetryRecoveryHandler.swift
 * OfficeKit
 *
 * Created by François Lamboley on 07/02/2020.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import URLRequestOperation



/**
 If the computeRetryInfo tells not to retry the operation and error is not nil,
 a custom handler is called that can tell to retry the operation anyway.
 
 Should probably be built-in URLRequestOperation tbh. */
open class URLRequestOperationWithRetryRecoveryHandler : URLRequestOperation {
	
	public typealias ComputeRetryInfoRecoverHandlerType = (_ operation: URLRequestOperationWithRetryRecoveryHandler, _ sourceError: Error, _ completionHandler: @escaping (URLRequestOperation.RetryMode, URLRequest, Error?) -> Void) -> Void
	public let retryInfoRecoveryHandler: ComputeRetryInfoRecoverHandlerType?
	
	public init(config c: URLRequestOperation.Config, retryInfoRecoveryHandler h: ComputeRetryInfoRecoverHandlerType? = nil) {
		retryInfoRecoveryHandler = h
		
		super.init(config: c)
	}
	
	open override func computeRetryInfo(sourceError error: Error?, completionHandler: @escaping (URLRequestOperation.RetryMode, URLRequest, Error?) -> Void) {
		super.computeRetryInfo(sourceError: error, completionHandler: { retryMode, request, error in
			if let h = self.retryInfoRecoveryHandler, let e = error, case .doNotRetry = retryMode {
				h(self, e, completionHandler)
			} else {
				completionHandler(retryMode, request, error)
			}
		})
	}
	
}
