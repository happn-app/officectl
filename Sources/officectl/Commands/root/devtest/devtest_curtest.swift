/*
 * devtest_curtest.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit
import SemiSingleton
import URLRequestOperation

#if canImport(DirectoryService) && canImport(OpenDirectory)
	import DirectoryService
	import OpenDirectory
#endif



func curTest(flags f: Flags, arguments args: [String], context: CommandContext) throws -> Future<Void> {
	var user = GoogleUser(email: Email(string: "toto@example.com")!)
	user.customerId = .set("42")
	print(Array(Mirror(reflecting: user).children))
	let encoder = JSONEncoder()
	let a = try encoder.encode(user)
	print(String(data: a, encoding: .utf8)!)
	return context.container.future()
	
//	let officeKitConfig: OfficeKitConfig = try context.container.make()
//	let semiSingletonStore: SemiSingletonStore = try context.container.make()
	
	/* Try and change OpenDirectory password via LDAP connection */
//	let ldapConnector = try LDAPConnector(ldapURL: URL(string: "ldap://od1.happn.private")!, protocolVersion: .v3, username: "uid=diradmin,cn=users,dc=office2,dc=happn,dc=private", password: "REDACTED")
//	return ldapConnector.connect(scope: (), eventLoop: context.container.eventLoop)
//	.then{
//		let op = try! ResetLDAPPasswordAction(key: User(id: UserId.distinguishedName(LDAPDistinguishedName(string: "uid=ldap.test,cn=users,dc=office2,dc=happn,dc=private"))), additionalInfo: context.container, store: semiSingletonStore)
//		return op.start(parameters: "toto", eventLoop: context.container.eventLoop)
//	}
	
	/* Connect to OpenDirectory */
	/* This helps: https://github.com/aosm/OpenDirectory/blob/master/Tests/TestApp.m */
//	#if canImport(DirectoryService) && canImport(OpenDirectory)
//	let op = BlockOperation{
//		do {
////			If needed, we have this equality that’s true (verified at runtime once…): kODRecordTypeUsers == kDSStdRecordTypeUsers
//			let testDN = try! LDAPDistinguishedName(string: "uid=ldap.test,cn=users,dc=office2,dc=happn,dc=private")
//
//			let session = try ODSession(options: [
//				kODSessionProxyAddress: "od1.happn.private",
//				kODSessionProxyUsername: "happn",
//				kODSessionProxyPassword: "REDACTED"
//			])
//			let node = try ODNode(session: session, type: ODNodeType(kODNodeTypeAuthentication))
////			try node.setCredentialsWithRecordType(kODRecordTypeUsers, recordName: "diradmin", password: "REDACTED")
//			/* Searching with the kODAttributeTypeMetaRecordName attribute does not
//			 * seem to work for whatever reason… */
//			let query = try ODQuery(node: node, forRecordTypes: kODRecordTypeUsers, attribute: kODAttributeTypeRecordName, matchType: ODMatchType(kODMatchEqualTo), queryValues: testDN.uid!, returnAttributes: nil, maximumResults: 0)
//			for r in try query.resultsAllowingPartial(false) {
//				print("current result: \(r)")
//				if let r = r as? ODRecord {
//					let detailsForMetaRecordName = try r.recordDetails(forAttributes: [kODAttributeTypeMetaRecordName])
//					print("kODAttributeTypeMetaRecordName: \(detailsForMetaRecordName)")
//					if let _ = try? r.verifyPassword("toto") {print("ok")}
//					else                                     {print("ko")}
//					guard try (r.recordDetails(forAttributes: [kODAttributeTypeMetaRecordName])[kODAttributeTypeMetaRecordName] as? [String])?.first == testDN.stringValue else {
//						print("NOT trying to set the password")
//						continue
//					}
//					print("Trying to set the password")
//					try r.setNodeCredentials("diradmin", password: "REDACTED")
//					try r.changePassword(nil, toPassword: "toto")
//				}
//			}
//		} catch {
//			print("got error: \(error)")
//		}
//	}
//	return Future<Void>.future(from: op, eventLoop: context.container.eventLoop, resultRetriever: { _ in () })
//	#else
//	throw NotAvailableOnThisPlatformError()
//	#endif
	
	/* List all GitHub project’s hooks */
//	let c = try GitHubJWTConnector(key: officeKitConfig.gitHubConfigOrThrow().connectorSettings)
//	let f = c.connect(scope: (), eventLoop: context.container.eventLoop)
//	.then{ _ -> Future<[GitHubRepository]> in
//		let op = GitHubRepositorySearchOperation(searchedOrganisation: "happn-app", gitHubConnector: c)
//		return Future<[GitHubRepository]>.future(from: op, eventLoop: context.container.eventLoop, resultRetriever: { try $0.result.get() })
//	}
//	.then{ repositories -> Future<[FutureResult<[Hook]>]> in
//		let ops = repositories.map{ rep -> AuthenticatedJSONOperation<[Hook]> in
//			var config = URLRequestOperation.Config(request: URLRequest(url: URL(string: "https://api.github.com/repos/" + rep.fullName + "/hooks")!), session: nil)
//			config.acceptableStatusCodes = nil
//			return AuthenticatedJSONOperation<[Hook]>(config: config, authenticator: { request, handler in
//				var request = request
//				request.addValue("Basic THIS_AWESOME_TOKEN", forHTTPHeaderField: "Authorization")
//				handler(.success(request), nil)
//			})
//		}
//		return Future<[FutureResult<[Hook]>]>.executeAll(ops, eventLoop: context.container.eventLoop)
//	}
//	.map{ hooks in
//		let hooks = Set(hooks.flatMap{ $0.result ?? [] }.filter{ $0.config.url.absoluteString.contains("email") })
//		let hooksStr = Data(hooks.reduce("", { $0 + $1.url.absoluteString + "\n" }).utf8)
//		_ = try? hooksStr.write(to: URL(fileURLWithPath: "/Users/frizlab/Desktop/toto.txt"))
//	}
//
//	struct Hook : Codable, Hashable {
//
//		var id: Int
//		var url: URL
//		var name: String
//
//		var config: Config
//
//		struct Config : Codable, Hashable {
//			var url: URL
//			var contentType: String
//		}
//
//	}
//
//	return f
	
	
	/* Modify Google user test */
//	let googleConnectorConfig = try officeKitConfig.googleConfigOrThrow().connectorSettings
//	_ = try nil2throw(googleConnectorConfig.userBehalf, "Google User Behalf")
//
//	let c = try GoogleJWTConnector(key: googleConnectorConfig)
//	let f = c.connect(scope: ModifyGoogleUserOperation.scopes, eventLoop: context.container.eventLoop)
//	.then{ _ -> Future<GoogleUser> in
//		let searchOp = GetGoogleUserOperation(userKey: "deletion.test@happn.fr", connector: c)
//		return Future<GoogleUser>.future(from: searchOp, eventLoop: context.container.eventLoop, resultRetriever: { try $0.result.get() })
//	}
//	.then{ user -> Future<Void> in
//		var user = user
//		user.name.familyName = "SuperTest"
//		let modifyUserOp = ModifyGoogleUserOperation(user: user, propertiesToUpdate: ["name"], connector: c)
//		return Future<Void>.future(from: modifyUserOp, eventLoop: context.container.eventLoop, resultRetriever: { _ in return })
//	}
//	return f
}
