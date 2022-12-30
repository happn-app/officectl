/*
 * DeleteOpenDirectoryRecordOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/07/19.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import Foundation
import OpenDirectory

import HasResult
import RetryingOperation



/* See <https://github.com/happn-app/RetryingOperation/blob/123eafbc84db6b1bbcab6849882de2ccd1f6e60e/Sources/RetryingOperation/WrappedRetryingOperation.swift#L36>
 *  for more info about the unchecked Sendable conformance. */
extension DeleteOpenDirectoryRecordOperation : @unchecked Sendable {}

public final class DeleteOpenDirectoryRecordOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = Void
	
	public let record: ODRecord
	public private(set) var result = Result<Void, Error>.failure(OperationIsNotFinishedError())
	
	public init(record r: ODRecord) {
		record = r
	}
	
	public override var isAsynchronous: Bool {
		return false
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		defer {self.baseOperationEnded()}
		
		do {
			try record.delete()
			result = .success(())
		} catch {
			result = .failure(error)
		}
	}
	
}

#endif
