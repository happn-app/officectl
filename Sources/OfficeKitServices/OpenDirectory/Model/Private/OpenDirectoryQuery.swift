/*
 * OpenDirectoryQuery.swift
 * OpenDirectoryOffice
 *
 * Created by François Lamboley on 2023/01/04.
 */

import OpenDirectory
import Foundation



/** Basically a wrapper for `ODQuery`, but without specifying the node. */
internal struct OpenDirectoryQuery : Sendable {
	
	init(uid: String, maxResults: Int? = nil, returnAttributes attr: [String]? = nil) {
		recordTypes = [kODRecordTypeUsers]
		attribute = kODAttributeTypeRecordName
		matchType = ODMatchType(kODMatchEqualTo)
		queryValues = [Data(uid.utf8)]
		returnAttributes = attr
		maximumResults = maxResults
	}
	
	init(guid: UUID, maxResults: Int? = nil, returnAttributes attr: [String]? = nil) {
		recordTypes = [kODRecordTypeUsers]
		attribute = kODAttributeTypeGUID
		matchType = ODMatchType(kODMatchEqualTo)
		queryValues = [Data(guid.uuidString.utf8)]
		returnAttributes = attr
		maximumResults = maxResults
	}
	
	init(recordTypes: [String], attribute: String?, matchType: ODMatchType, queryValues: [Data]?, returnAttributes: [String]?, maximumResults: Int?) {
		self.recordTypes = recordTypes
		self.attribute = attribute
		self.matchType = matchType
		self.queryValues = queryValues
		self.returnAttributes = returnAttributes
		self.maximumResults = maximumResults
	}
	
	var recordTypes: [String]
	var attribute: String?
	var matchType: ODMatchType
	var queryValues: [Data]?
	var returnAttributes: [String]?
	var maximumResults: Int?
	
	@ODActor
	func odQuery(node: ODNode) throws -> ODQuery {
		/* Note: This shortcut exists when searching directly with a UID:
		 *        try node.record(withRecordType: kODRecordTypeUsers, name: the_uid (e.g. "francois.lamboley"), attributes: request.returnAttributes) */
		return try ODQuery(
			node: node,
			forRecordTypes: recordTypes,
			attribute: attribute,
			matchType: matchType,
			queryValues: queryValues,
			returnAttributes: returnAttributes/* ?? kODAttributeTypeAllAttributes*/,
			maximumResults: maximumResults ?? 0
		)
	}
	
	@ODActor
	func execute(on node: ODNode) throws -> [ODRecord] {
		let odQuery = try odQuery(node: node)
		/* The “as!” should be valid: OpenDirectory is simply not updated anymore and the returned array is not typed.
		 * Doc says this method returns an array of ODRecord. */
		return try odQuery.resultsAllowingPartial(false) as! [ODRecord]
	}
	
}
