/*
 * User+OpenDirectory.swift
 * OfficeKit
 *
 * Created by François Lamboley on 21/05/2019.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import Foundation
import OpenDirectory

import SemiSingleton
import Vapor


#warning("This file should not be needed anymore.")

#if false
extension User {
	
	public func bestOpenDirectorySearchQuery(officeKitConfig: OfficeKitConfig) throws -> OpenDirectorySearchRequest {
		if let email = email {
			return OpenDirectorySearchRequest(recordTypes: [kODRecordTypeUsers], attribute: kODAttributeTypeRecordName, matchType: ODMatchType(kODMatchEqualTo), queryValues: [Data(email.username.utf8)], returnAttributes: nil, maximumResults: 2)
		}
		throw InvalidArgumentError(message: "Cannot find an OpenDirectory query to fetch user with id “\(id)”")
	}
	
}

#endif
#endif
