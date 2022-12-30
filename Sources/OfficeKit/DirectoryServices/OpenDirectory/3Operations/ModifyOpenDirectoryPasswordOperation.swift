/*
 * ModifyOpenDirectoryPasswordOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2018/09/11.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import Foundation
import OpenDirectory

import HasResult
import RetryingOperation



/* See <https://github.com/happn-app/RetryingOperation/blob/123eafbc84db6b1bbcab6849882de2ccd1f6e60e/Sources/RetryingOperation/WrappedRetryingOperation.swift#L36>
 *  for more info about the unchecked Sendable conformance. */
extension ModifyOpenDirectoryPasswordOperation : @unchecked Sendable {}

public final class ModifyOpenDirectoryPasswordOperation : RetryingOperation, HasResult {
	
	public let record: ODRecord
	public let newPassword: String
	
	public private(set) var result = Result<Void, Error>.failure(OperationIsNotFinishedError())
	
	public init(record r: ODRecord, newPassword p: String) {
		record = r
		newPassword = p
	}
	
	public override var isAsynchronous: Bool {
		return false
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		defer {self.baseOperationEnded()}
		
		do {
			try record.changePassword(nil, toPassword: newPassword)
			result = .success(())
		} catch {
			result = .failure(error)
		}
	}
	
}

#endif
