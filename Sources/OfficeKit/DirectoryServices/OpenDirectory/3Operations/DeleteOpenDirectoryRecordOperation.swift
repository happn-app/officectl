/*
 * DeleteOpenDirectoryRecordOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 19/07/2019.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import Foundation
import OpenDirectory

import RetryingOperation



public final class DeleteOpenDirectoryRecordOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = Void
	
	public let authenticator: OpenDirectoryRecordAuthenticator
	
	public let record: ODRecord
	public private(set) var result = Result<Void, Error>.failure(OperationIsNotFinishedError())
	
	public init(record r: ODRecord, authenticator a: OpenDirectoryRecordAuthenticator) {
		record = r
		authenticator = a
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		authenticator.authenticate(request: record, handler: { r, _ in
			do {
				let authenticatedRecord = try r.get()
				try authenticatedRecord.delete()
				self.result = .success(())
			} catch {
				self.result = .failure(error)
			}
			self.baseOperationEnded()
		})
	}
	
}

#endif
