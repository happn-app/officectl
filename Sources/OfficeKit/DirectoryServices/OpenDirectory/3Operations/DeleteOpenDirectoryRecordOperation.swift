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
