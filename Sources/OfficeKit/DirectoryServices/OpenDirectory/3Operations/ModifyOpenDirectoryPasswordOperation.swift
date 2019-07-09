/*
 * ModifyOpenDirectoryPasswordOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 11/09/2018.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import Foundation
import OpenDirectory

import RetryingOperation



public final class ModifyOpenDirectoryPasswordOperation : RetryingOperation, HasResult {
	
	public let authenticator: OpenDirectoryRecordAuthenticator
	
	public let record: ODRecord
	public let newPassword: String
	
	public private(set) var error: Error? = OperationIsNotFinishedError()
	public func resultOrThrow() throws -> Void {
		try throwIfError(error)
		return ()
	}
	
	public init(record r: ODRecord, newPassword p: String, authenticator a: OpenDirectoryRecordAuthenticator) {
		record = r
		newPassword = p
		authenticator = a
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		authenticator.authenticate(request: record, handler: { result, userInfo in
			do {
				let record = try result.get()
				try record.changePassword(nil, toPassword: self.newPassword)
				self.error = nil
			} catch let err {
				self.error = err
			}
			self.baseOperationEnded()
		})
	}
	
}

#endif
