/*
 * CloudflareAuthenticator.swift
 * CloudflareZeroTrustOffice
 *
 * Created by François Lamboley on 2023/07/21.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import APIConnectionProtocols
import TaskQueue



public actor CloudflareAuthenticator : Authenticator, HasTaskQueue {
	
	public typealias Request = URLRequest
	
	public let token: String
	
	public init(token: String) {
		self.token = token
	}
	
	/* ************************************
	   MARK: - Authenticator Implementation
	   ************************************ */
	
	public func unqueuedAuthenticate(request: URLRequest) async throws -> URLRequest {
		/* Add the expected header to the request. */
		var request = request
		request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		return request
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/** Technically public because it fulfill the HasTaskQueue requirement, but should not be used directly. */
	public var _taskQueue = TaskQueue()
	
}
