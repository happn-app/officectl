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



public final class SearchOpenDirectoryOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = [ODRecord]
	
	public let openDirectoryConnector: OpenDirectoryConnector
	public let request: OpenDirectorySearchRequest
	
	public private(set) var results = Result<ResultType, Error>.failure(OperationIsNotFinishedError())
	public var result: Result<[ODRecord], Error> {return results}
	
	public convenience init(uid: String, maxResults: Int? = nil, returnAttributes: [String]? = nil, openDirectoryConnector c: OpenDirectoryConnector) {
		let request = OpenDirectorySearchRequest(uid: uid, maxResults: maxResults, returnAttributes: returnAttributes)
		self.init(request: request, openDirectoryConnector: c)
	}
	
	public init(request r: OpenDirectorySearchRequest, openDirectoryConnector c: OpenDirectoryConnector) {
		request = r
		openDirectoryConnector = c
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		defer {baseOperationEnded()}
		
		do {
			try openDirectoryConnector.performOpenDirectoryCommunication{ node in
				guard let node = node else {
					throw InternalError(message: "Launched a search open directory action with a non-connected connector!")
				}
				/* Note: This shortcut exists when searching directly with a UID:
				 *       try node.record(withRecordType: kODRecordTypeUsers, name: the_uid (e.g. "francois.lamboley"), attributes: request.returnAttributes) */
				let odQuery = try ODQuery(
					node: node,
					forRecordTypes: request.recordTypes,
					attribute: request.attribute,
					matchType: request.matchType,
					queryValues: request.queryValues,
					returnAttributes: request.returnAttributes/* ?? kODAttributeTypeAllAttributes*/,
					maximumResults: request.maximumResults ?? 0
				)
				/* The “as!” should be valid; OpenDirectory is simply not updated anymore and the returned array is not typed.
				 * But doc says this method returns an array of ODRecord. */
				let odResults = try odQuery.resultsAllowingPartial(false) as! [ODRecord]
				results = .success(odResults)
			}
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
	
	public init(uid: String, maxResults: Int? = nil, returnAttributes attr: [String]? = nil) {
		recordTypes = [kODRecordTypeUsers]
		attribute = kODAttributeTypeRecordName
		matchType = ODMatchType(kODMatchEqualTo)
		queryValues = [Data(uid.utf8)]
		returnAttributes = attr
		maximumResults = maxResults
	}
	
	public init(recordTypes rt: [String], attribute attr: String?, matchType mt: ODMatchType, queryValues qv: [Data]?, returnAttributes ra: [String]?, maximumResults mr: Int?) {
		recordTypes = rt
		attribute = attr
		matchType = mt
		queryValues = qv
		returnAttributes = ra
		maximumResults = mr
	}
	
	public var recordTypes: [String]
	public var attribute: String?
	public var matchType: ODMatchType
	public var queryValues: [Data]?
	public var returnAttributes: [String]?
	public var maximumResults: Int?
	
}

#endif
