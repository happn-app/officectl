/*
 * CreateOpenDirectoryRecordOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/07/12.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import Foundation
import OpenDirectory

import Email
import HasResult
import RetryingOperation



public final class CreateOpenDirectoryRecordOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = ODRecord
	
	public let openDirectoryConnector: OpenDirectoryConnector
	
	public let recordType: String
	public let recordName: String
	public let recordAttributes: [AnyHashable: Any]
	public private(set) var result = Result<ODRecord, Error>.failure(OperationIsNotFinishedError())
	
	public convenience init(user: ODRecordOKWrapper, connector: OpenDirectoryConnector) throws {
		guard let userId = user.userId.uid else {
			throw InvalidArgumentError(message: "No uid in user asked to be created.")
		}
		guard let firstNameValue = user.firstName.value, let firstName = firstNameValue else {
			throw InvalidArgumentError(message: "No firstName in user asked to be created.")
		}
		guard let lastNameValue = user.lastName.value, let lastName = lastNameValue else {
			throw InvalidArgumentError(message: "No lastName in user asked to be created.")
		}
		self.init(userId: userId, firstName: firstName, lastName: lastName, fullName: nil, emails: user.emails, connector: connector)
	}
	
	/**
	 If fullName is `nil`, it’ll be inferred by concatenating the first and last name, separated by a space. */
	public convenience init(userId: String, firstName: String, lastName: String, fullName: String? = nil, emails: [Email] = [], groupId: String = "20", nfsHomeDirectory: String? = "/dev/null", shell: String? = "/usr/bin/false", connector: OpenDirectoryConnector) {
		var attributes = [
			kODAttributeTypeFirstName: [firstName],
			kODAttributeTypeLastName: [lastName],
			kODAttributeTypeFullName: [fullName ?? firstName + " " + lastName],
			kODAttributeTypeEMailAddress: emails.map{ $0.rawValue },
			kODAttributeTypePrimaryGroupID: [groupId]
		]
		if let shell = shell           {attributes[kODAttributeTypeUserShell]        = [shell]}
		if let home = nfsHomeDirectory {attributes[kODAttributeTypeNFSHomeDirectory] = [home]}
		self.init(recordType: kODRecordTypeUsers, recordName: userId, recordAttributes: attributes, connector: connector)
	}
	
	public init(recordType t: String, recordName n: String, recordAttributes attrs: [AnyHashable: Any], connector: OpenDirectoryConnector) {
		recordType = t
		recordName = n
		recordAttributes = attrs
		openDirectoryConnector = connector
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		Task{
			result = await Result{
				try await openDirectoryConnector.performOpenDirectoryCommunication{ node in
					guard let node = node else {
						throw InternalError(message: "Launched a search open directory action with a non-connected connector!")
					}
					
					/* Let’s first search all the record of given type (trust me on this, we’ll need them; see later). */
					let odQuery = try ODQuery(
						node: node,
						forRecordTypes: [recordType],
						attribute: kODAttributeTypeMetaRecordName,
						matchType: ODMatchType(kODMatchAny),
						queryValues: nil,
						returnAttributes: kODAttributeTypeUniqueID,
						maximumResults: 0
					)
					/* See SearchOpenDirectoryOperation for the force unwrap. */
					let odResults = try odQuery.resultsAllowingPartial(false) as! [ODRecord]
					/* Now find the max UID of these records.
					 * We start at 501; users with a UID <= 500 are invisble. */
					var maxUID = 501
					for odResult in odResults {
						/* The kODAttributeTypeUniqueID should already be fetched, so asking for nil here is ok. */
						let attributes = try odResult.recordDetails(forAttributes: nil)
						guard let uids = attributes[kODAttributeTypeUniqueID] as? [Any] else {
							continue
						}
						for uid in uids {
							switch uid {
								case let str as String:
									guard let uidInt = Int(str) else {
										OfficeKitConfig.logger?.warning("Found non-int string uid \(str) in OpenDirectory record \(odResult)")
										continue
									}
									maxUID = max(maxUID, uidInt)
									
								case let data as Data:
									guard let str = String(data: data, encoding: .utf8), let uidInt = Int(str) else {
										OfficeKitConfig.logger?.warning("Found non-int data uid \(data) in OpenDirectory record \(odResult)")
										continue
									}
									maxUID = max(maxUID, uidInt)
									
								default:
									OfficeKitConfig.logger?.warning("Found non-data and non-string uid \(uid) in OpenDirectory record \(odResult)")
							}
						}
					}
					
					var attrs = recordAttributes
					attrs[kODAttributeTypeUniqueID] = [String(maxUID + 1)]
					let createdNode = try node.createRecord(withRecordType: recordType, name: recordName, attributes: attrs)
					_ = try? createdNode.recordDetails(forAttributes: [kODAttributeTypeMetaRecordName]) /* We prefetch the record name for ease of future use */
					return createdNode
				}
			}
			baseOperationEnded()
		}
	}
	
}

#endif
