/*
 * sync.swift
 * officectl
 *
 * Created by François Lamboley on 13/07/2018.
 */

import Foundation

import AsyncOperationResult
import Guaka
import Vapor

import OfficeKit



private enum Service : String {
	
	case ldap
	case google
	case github
	
}

struct Connectors {
	
	var ldapConnector: LDAPConnector!
	var googleConnector: GoogleJWTConnector!
	
	init() {
	}
	
}

func sync(flags f: Flags, arguments args: [String], context: CommandContext) throws -> EventLoopFuture<Void> {
	let asyncConfig: AsyncConfig = try context.container.make()
	
	var connectors = Connectors()
	var service2FutureUsers = [Service: EventLoopFuture<(Service, [User])>]()
	
	
	/* *** Parse command line options *** */
	let googleDomain: String!
	let fromStr = f.getString(name: "from")!
	let ldapBasePeopleDN: LDAPDistinguishedName!
	guard let fromService = Service(rawValue: fromStr) else {
		throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid \"from\" value for syncing directories: \(fromStr)"])
	}
	let toServices = try f.getString(name: "to")!.split(separator: ",").map{ substr -> Service in
		let strService = String(substr)
		guard let s = Service(rawValue: strService) else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid \"to\" value for syncing directories: \(strService)"])
		}
		return s
	}
	if fromService == .ldap || toServices.contains(.ldap) {
		guard let baseDNString = f.getString(name: "ldap-base-dn") else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "The \"ldap-base-dn\" option is required when syncing to or from LDAP"])
		}
		guard let peopleOrganizationUnitString = f.getString(name: "ldap-people-organization-unit") else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "The \"ldap-people-organization-unit\" option is required when syncing to or from LDAP"])
		}
		ldapBasePeopleDN = try LDAPDistinguishedName(values: [(key: "ou", value: peopleOrganizationUnitString)]) + LDAPDistinguishedName(string: baseDNString)
	} else {
		ldapBasePeopleDN = nil
	}
	if fromService == .google || toServices.contains(.google) {
		guard let d = f.getString(name: "google-domain") else {
			throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "The \"google-domain\" option is required when syncing to or from Google"])
		}
		googleDomain = d
	} else {
		googleDomain = nil
	}
	
	/* *** Connect services connectors and retrieve all (future) users from required services *** */
	for s in [fromService] + toServices {
		guard service2FutureUsers[s] == nil else {continue}
		switch s {
		case .google:
			guard let userBehalf = f.getString(name: "google-admin-email") else {
				throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "The \"google-admin-email\" option is required when syncing Google"])
			}
			connectors.googleConnector = try GoogleJWTConnector(flags: f, userBehalf: userBehalf)
			service2FutureUsers[s] =
				connectors.googleConnector.connect(scope: SearchGoogleUsersOperation.scopes, asyncConfig: asyncConfig)
				.then{ usersFromGoogle(connector: connectors.googleConnector, searchedDomain: googleDomain, baseDN: ldapBasePeopleDN, asyncConfig: asyncConfig) }
			
		case .ldap:
			connectors.ldapConnector = try LDAPConnector(flags: f)
			service2FutureUsers[s] =
				connectors.ldapConnector.connect(scope: (), asyncConfig: asyncConfig)
				.then{ usersFromLDAP(connector: connectors.ldapConnector, baseDN: ldapBasePeopleDN, asyncConfig: asyncConfig) }
			
		case .github: throw NSError(domain: "com.happn.officectl", code: 255, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
		}
	}
	
	/* *** Launch sync *** */
	let f = EventLoopFuture.reduce(into: [Service: [User]](), Array(service2FutureUsers.values), eventLoop: asyncConfig.eventLoop, { currentValue, newValue in
		let (service, users) = newValue
		currentValue[service] = users
	})
	.then{ (usersByService) -> EventLoopFuture<Void> in
		do {
			switch fromService {
			case .google:
				let syncFutures = try toServices.map{ (destinationService) -> EventLoopFuture<Void> in
					switch destinationService {
					case .github: throw NotImplementedError()
					case .google: throw BasicValidationError("Cannot sync from Google to Google…")
					case .ldap:
						let (future, operation) = syncFromGoogleToLDAP(users: usersByService, baseDN: ldapBasePeopleDN, connectors: connectors, asyncConfig: asyncConfig)
						return future
						.catch{ error in
							context.console.error("Got error while creating users: \(error)")
						}
						.always{
							context.console.print("Generated the following users:")
							for (dn, password) in operation.passwords {
								context.console.print("   " + dn + ": " + password)
							}
						}
					}
				}
				return EventLoopFuture.reduce(into: (), syncFutures, eventLoop: asyncConfig.eventLoop, { currentValue, newValue in })
				
			case .ldap:
				throw NotImplementedError()
				
			case .github:
				throw BasicValidationError("Cannot sync from GitHub (GitHub’s directory does not have enough information)")
			}
		} catch {
			return asyncConfig.eventLoop.newFailedFuture(error: error)
		}
	}
	return f
}

/** - returns: A future and a `ModifyLDAPPasswordsOperation`. You can retrieve
the dn<->password mappings for created objects from the operation. Use the
future to know when the objects creation is over. Note that even in case of
failures, you might still get users created; you should always check the
operation for passwords. */
private func syncFromGoogleToLDAP(users: [Service: [User]], baseDN: LDAPDistinguishedName, connectors: Connectors, asyncConfig: AsyncConfig) -> (EventLoopFuture<Void>, ModifyLDAPPasswordsOperation) {
	/* TODO: User deletion. Currently we’re append only. */
	let ldapUsers = Set(users[.ldap]!)
	let googleUsers = Set(users[.google]!)
	let usersToCreate = googleUsers.subtracting(ldapUsers)
	
	let ldapUsersToCreate = usersToCreate.compactMap{ try? $0.ldapInetOrgPerson(baseDN: baseDN) }
	let createUsersOperation = CreateLDAPObjectsOperation(users: ldapUsersToCreate, connector: connectors.ldapConnector)
	let changePasswordsOperation = ModifyLDAPPasswordsOperation(users: ldapUsersToCreate, connector: connectors.ldapConnector)
	changePasswordsOperation.addDependency(createUsersOperation)
	
	let f: Future<[Void]> = asyncConfig.eventLoop.future(from: [createUsersOperation, changePasswordsOperation], queue: asyncConfig.operationQueue, resultRetriever: { _ in return () })
	return (f.transform(to: ()), changePasswordsOperation)
}

private func usersFromGoogle(connector: GoogleJWTConnector, searchedDomain: String, baseDN: LDAPDistinguishedName, asyncConfig: AsyncConfig) -> EventLoopFuture<(Service, [User])> {
	let searchOp = SearchGoogleUsersOperation(searchedDomain: searchedDomain, googleConnector: connector)
	return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.operationQueue, resultRetriever: {
		(.google, try $0.result.successValueOrThrow().map{ User(googleUser: $0, baseDN: baseDN) })
	})
}

private func usersFromLDAP(connector: LDAPConnector, baseDN: LDAPDistinguishedName, asyncConfig: AsyncConfig) -> EventLoopFuture<(Service, [User])> {
	let searchOp = SearchLDAPOperation(ldapConnector: connector, request: LDAPSearchRequest(scope: .children, base: baseDN, searchQuery: nil, attributesToFetch: nil))
	return asyncConfig.eventLoop.future(from: searchOp, queue: asyncConfig.operationQueue, resultRetriever: {
		(.ldap, try $0.results.successValueOrThrow().results.compactMap{ $0.inetOrgPerson }.compactMap{ User(ldapInetOrgPerson: $0) })
	})
}
