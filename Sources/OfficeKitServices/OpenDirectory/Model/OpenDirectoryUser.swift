/*
 * OpenDirectoryUser.swift
 * OpenDirectoryOffice
 *
 * Created by François Lamboley on 2022/12/30.
 */

import Foundation
import OpenDirectory

import OfficeKit2



/* We do not use ODRecord because they cannot be created without either retrieving an existing record from a node or creating a new record in a node. */
public struct OpenDirectoryUser : Sendable, Codable {
	
	public static let recordType: String = kODRecordTypeUsers
	
	/* kODAttributeTypeMetaRecordName
	 * We do not store it in properties because we want it to never be nil. */
	public var id: LDAPDistinguishedName
	/** All of the properties of the user except for its id. */
	public var properties = [String: OpenDirectoryAttributeValue]()
	
	public init(id: LDAPDistinguishedName) {
		self.id = id
	}
	
	/**
	 Initialiazes an ``OpenDirectoryUser`` with an ODRecord.
	 
	 We do not ask for a record directly, but instead we ask for a _Sendable_ block that returns a record.
	 
	 The reason for this is `ODRecord` is not (AFAIK) Sendable.
	 Even considering the fact `OpenDirectory` pre-dates Swift, I don’t think `OpenDirectory` is even thread-safe (if it is, it is not documented).
	 
	 So we have to be careful how to use records and avoid passing them through async contexts.
	 
	 To do this we have created an actor wrapper for the `ODRecord`.
	 Everything happening on the record should happen in the wrapper async context.
	 Including the creation of the record itself, which will thus be done in the `recordGetter`.
	 
	 Obviously the client must not keep a reference to the `ODRecord` after returning it in the `recordGetter` block. */
	internal init?(recordGetter: @Sendable () throws -> ODRecord?) async throws {
		let properties: [String: OpenDirectoryAttributeValue]? = try await _record.perform{ wrappedRecord in
			guard let record = try recordGetter() else {
				return nil
			}
			wrappedRecord = record
			
			guard record.recordType == Self.recordType else {
				/* Invalid init of OpenDirectoryUser. */
				throw Err.internalError
			}
			/* This should not throw ever because we’re asking for the attributes already in memory (nil list). */
			guard let attributes = try record.recordDetails(forAttributes: nil) as? [String: Any] else {
				/* We believe recordDetails(forAttributes:) actually returns a [String: Any], not a [AnyHashable: Any] but that because of OpenDirectory not being updated the type is incorrect. */
				throw Err.internalError
			}
			return try attributes.mapValues{ try OpenDirectoryAttributeValue(any: $0) }
		}
		guard var properties else {
			return nil
		}
		
		guard let idStr = properties[kODAttributeTypeMetaRecordName]?.asString else {
			/* I don’t think it’s possible to get a user record (or any record tbh) without a record name. */
			throw Err.internalError
		}
		properties.removeValue(forKey: kODAttributeTypeMetaRecordName)
		let id = try LDAPDistinguishedName(string: idStr)
		
		self.id = id
		self.properties = properties
	}
	
	/* With the OpenDirectory framework, unless I’m mistaken, to change a record one *must* have the an ODRecord object representing the current record.
	 * To avoid fetching the record for each modification when we already have fetched it, we keep a cached version of it.
	 * Because ODRecord is (presumably) not thread safe, we confine it to an actor.
	 *
	 * I do not declare this as “`@ODObjectWrapper var record: ODRecord?`” because
	 *   1. for semi-explained reasons if I do this the struct does not automatically conforms to Codable.
	 *      This kind of makes sense as the wrapper variable is not optional.
	 *      However setting an initial value (“`@ODObjectWrapper var record: ODRecord? = nil`”) does not solve the issue.
	 *      It might be an oversight of the automatic Codable conformance, but honestly I’m not sure.
	 *   2. For fully unexplained reasons, using the wrapper seems to remove some concurrency protections.
	 *      With the wrapper, the call to `perform(_:)` in `init(recordGetter:)` is not considered async, which is weird… */
	internal var _record: ODObjectWrapper<ODRecord?> = .init()
	
	private enum CodingKeys : CodingKey {
		case id
		case properties
	}
	
}
