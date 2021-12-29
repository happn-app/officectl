/*
 * SearchGoogleUsers.swift
 * officectl
 *
 * Created by François Lamboley on 2020/01/09.
 */

import Foundation

import Email
import OfficeKit
import Vapor



struct EmailSrcAndDst : Hashable, CustomDebugStringConvertible {
	
	var source: String
	var destination: String
	
	init(emailStr: String, disabledUserSuffix: String?, logger: Logger?) {
		guard let email = Email(rawValue: emailStr) else {
			logger?.warning("Got a filter for backuping emails which is not an email (\(emailStr)). Not considered for disabled suffix check.")
			destination = emailStr
			source = emailStr
			return
		}
		guard let disabledUserSuffix = disabledUserSuffix else {
			destination = emailStr
			source = emailStr
			return
		}
		
		let hasSuffix = email.localPart.hasSuffix(disabledUserSuffix)
		/* We rebuild the email without checking for validity so we do not recreate an Email object in the two lines below. */
		source      = hasSuffix ? email.rawValue : (email.localPart + disabledUserSuffix + "@" + email.domainPart)
		destination = hasSuffix ? (email.localPart.dropLast(disabledUserSuffix.count) + "@" + email.domainPart) : email.rawValue
	}
	
	var debugDescription: String {
		guard source != destination else {return source}
		return "(" + source + "," + destination + ")"
	}
	
}

struct GoogleUserAndDest {
	
	static func fetchListToBackup(
		googleConfig: GoogleServiceConfig, googleConnector: GoogleJWTConnector,
		usersFilter: [EmailSrcAndDst]?, disabledUserSuffix: String?,
		downloadsDestinationFolder: URL, archiveDestinationFolder: URL?,
		skipIfArchiveFound: Bool,
		console: Console, opQ: OperationQueue
	) async throws -> [GoogleUserAndDest] {
		/* Fetch users */
		let ops = googleConfig.primaryDomains.map{ SearchGoogleUsersOperation(searchedDomain: $0, googleConnector: googleConnector) }
		let allUsers = try await opQ.addOperationsAndGetResults(ops).map{ try $0.get() }.flatMap{ $0 }
		
		/* Find mails to backup */
		let allUsersFilter = usersFilter?.flatMap{ Set(arrayLiteral: $0.source, $0.destination) }
		let filteredUsers = allUsers
			.filter{ allUsersFilter?.contains($0.primaryEmail.rawValue) ?? true }
			.map{ GoogleUserAndDest(googleUser: $0, disabledUserSuffix: disabledUserSuffix, downloadsURL: downloadsDestinationFolder, archiveURL: archiveDestinationFolder) }
			.filter{ !skipIfArchiveFound || !($0.archiveDestination.flatMap{ FileManager.default.fileExists(atPath: $0.path) } ?? false) } /* Not optimal but we don’t care. */
		
		/* Let’s check if two users have the same download or archive destination.
		 * We fail if this happens.
		 * The whole process is most likely sub-optimal in this implementation but we don’t care, really. */
		let downloadsDestinationsSet = Set(filteredUsers.map{ $0.downloadDestination })
		guard filteredUsers.count == downloadsDestinationsSet.count else {
			throw InvalidArgumentError(message: "Got two users whose destination for the downloads is the same.")
		}
		let archiveDestinations = filteredUsers.map{ $0.archiveDestination }
		let nNilArchiveDestinations = archiveDestinations.reduce(0, { $1 == nil ? $0 + 1 : $0 })
		let archiveDestinationsSet = Set(archiveDestinations.compactMap{ $0 })
		guard filteredUsers.count - nNilArchiveDestinations == archiveDestinationsSet.count else {
			throw InvalidArgumentError(message: "Got two users whose destination for the archives is the same.")
		}
		
		guard filteredUsers.count > 0 else {
			console.info("No users to backup.")
			return []
		}
		
		return filteredUsers
	}
	
	var user: GoogleUser
	var downloadDestination: URL
	var archiveDestination: URL?
	
	init(googleUser: GoogleUser, disabledUserSuffix: String?, downloadsURL: URL, archiveURL: URL?) {
		let emailSrcAndDst = EmailSrcAndDst(emailStr: googleUser.primaryEmail.rawValue, disabledUserSuffix: disabledUserSuffix, logger: nil)
		
		user = googleUser
		downloadDestination = downloadsURL.appendingPathComponent(emailSrcAndDst.destination)
		archiveDestination = archiveURL.flatMap{ $0.appendingPathComponent(emailSrcAndDst.destination).appendingPathExtension("tar.bz2") }
	}
	
}
