/*
 * SearchOpenDirectoryOperation.swift
 * officectl
 *
 * Created by François Lamboley on 21/05/2019.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import Foundation
import OpenDirectory

import RetryingOperation



public class SearchOpenDirectoryOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = [ODRecord]
	
	public let openDirectoryConnector: OpenDirectoryConnector
	public let request: OpenDirectorySearchRequest
	
	public private(set) var results = Result<ResultType, Error>.failure(OperationIsNotFinishedError())
	public func resultOrThrow() throws -> ResultType {
		return try results.get()
	}
	
	public init(openDirectoryConnector c: OpenDirectoryConnector, request r: OpenDirectorySearchRequest) {
		openDirectoryConnector = c
		request = r
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		assert(openDirectoryConnector.isConnected)
		defer {baseOperationEnded()}
		
		do {
			let odQuery = try ODQuery(
				node: openDirectoryConnector.node!,
				forRecordTypes: request.recordTypes,
				attribute: request.attribute,
				matchType: request.matchType,
				queryValues: request.queryValues,
				returnAttributes: request.returnAttributes,
				maximumResults: request.maximumResults ?? 0
			)
			/* The as! should be valid; OpenDirectory is simply not updated anymore
			 * and the returned array is not typed. But doc says this method
			 * returns an array of ODRecord. */
			let odResults = try odQuery.resultsAllowingPartial(false) as! [ODRecord]
			results = .success(odResults)
		} catch {
			results = .failure(error)
		}
	}
	
	public override var isAsynchronous: Bool {
		return false
	}
	
}

/** Basically a wrapper for `ODQuery`, but without specifying the node. */
public struct OpenDirectorySearchRequest {
	
	var recordTypes: [String]
	var attribute: String
	var matchType: ODMatchType
	var queryValues: [Data]
	var returnAttributes: [String]?
	var maximumResults: Int?
	
}

#endif
