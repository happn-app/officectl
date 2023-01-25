/*
 * VaultPKIAuthenticator.swift
 * VaultPKIOffice
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import APIConnectionProtocols
import TaskQueue



public actor VaultPKIAuthenticator : Authenticator, HasTaskQueue {
	
	public typealias Request = URLRequest
	
	public let rootToken: String
	
	public init(rootToken: String) {
		self.rootToken = rootToken
	}
	
	/* ************************************
	   MARK: - Authenticator Implementation
	   ************************************ */
	
	public func unqueuedAuthenticate(request: URLRequest) async throws -> URLRequest {
		/* Add the “Authorization” header to the request. */
		var request = request
		request.addValue(rootToken, forHTTPHeaderField: "X-Vault-Token")
		return request
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/** Technically public because it fulfill the HasTaskQueue requirement, but should not be used directly. */
	public var _taskQueue = TaskQueue()
	
}
