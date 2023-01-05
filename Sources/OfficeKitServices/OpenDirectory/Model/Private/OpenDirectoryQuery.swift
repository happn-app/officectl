/*
 * OpenDirectoryQuery.swift
 * OpenDirectoryOffice
 *
 * Created by François Lamboley on 2023/01/04.
 */

import Foundation
import OpenDirectory



/** Basically a wrapper for `ODQuery`, but without specifying the node. */
internal struct OpenDirectoryQuery : Sendable {
	
	init(uid: String, maxResults: Int? = nil, returnAttributes: Set<String>? = nil) {
		self.recordTypes = [kODRecordTypeUsers]
		self.attribute = kODAttributeTypeRecordName
		self.matchType = ODMatchType(kODMatchEqualTo)
		self.queryValues = [Data(uid.utf8)]
		self.returnAttributes = returnAttributes
		self.maximumResults = maxResults
	}
	
	init(guid: UUID, maxResults: Int? = nil, returnAttributes: Set<String>? = nil) {
		self.recordTypes = [kODRecordTypeUsers]
		self.attribute = kODAttributeTypeGUID
		self.matchType = ODMatchType(kODMatchEqualTo)
		self.queryValues = [Data(guid.uuidString.utf8)]
		self.returnAttributes = returnAttributes
		self.maximumResults = maxResults
	}
	
	static func forAllUsers(returnAttributes: Set<String>? = nil) -> OpenDirectoryQuery {
		return .init(
			recordTypes: [kODRecordTypeUsers],
			attribute: kODAttributeTypeMetaRecordName,
			matchType: ODMatchType(kODMatchAny),
			queryValues: nil,
			returnAttributes: returnAttributes,
			maximumResults: nil
		)
	}
	
	init(recordTypes: Set<String>, attribute: String?, matchType: ODMatchType, queryValues: [Data]?, returnAttributes: Set<String>?, maximumResults: Int?) {
		self.recordTypes = recordTypes
		self.attribute = attribute
		self.matchType = matchType
		self.queryValues = queryValues
		self.returnAttributes = returnAttributes
		self.maximumResults = maximumResults
	}
	
	var recordTypes: Set<String>
	var attribute: String?
	var matchType: ODMatchType
	var queryValues: [Data]?
	var returnAttributes: Set<String>?
	var maximumResults: Int?
	
	@ODActor
	func odQuery(node: ODNode) throws -> ODQuery {
		/* Note: This shortcut exists when searching directly with a UID:
		 *        try node.record(withRecordType: kODRecordTypeUsers, name: the_uid (e.g. "francois.lamboley"), attributes: request.returnAttributes) */
		return try ODQuery(
			node: node,
			forRecordTypes: Array(recordTypes),
			attribute: attribute,
			matchType: matchType,
			queryValues: queryValues,
			returnAttributes: returnAttributes.flatMap(Array.init)/* ?? kODAttributeTypeAllAttributes*/,
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
