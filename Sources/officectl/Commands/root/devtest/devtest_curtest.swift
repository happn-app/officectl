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
	#if canImport(DirectoryService) && canImport(OpenDirectory)
	let serviceConfig: OpenDirectoryServiceConfig = try context.container.make(OfficectlConfig.self).officeKitConfig.getServiceConfig(id: nil)
	let authenticator: OpenDirectoryRecordAuthenticator = try context.container.makeSemiSingleton(forKey: serviceConfig.authenticatorSettings)
	let connector: OpenDirectoryConnector = try context.container.makeSemiSingleton(forKey: serviceConfig.connectorSettings)
	return connector.connect(scope: (), eventLoop: context.container.eventLoop)
	.then{
		return Future<ODRecord>.future(from: SearchOpenDirectoryOperation(uid: "diradmin", openDirectoryConnector: connector), eventLoop: context.container.eventLoop)
	}
	.map{ record in
		print(record)
		//"uid=hello.world,cn=users,dc=office2,dc=happn,dc=private"
		_ = try connector.performOpenDirectoryCommunication{ node in
			guard let node = node else {return}
			
			try print(node.subnodeNames())
//			try print(node.unreachableSubnodeNames())
//			try node.setCredentialsWithRecordType(kODRecordTypeUsers, recordName: "diradmin", password: "readacts22169.drawsily")
			try node.createRecord(withRecordType: kODRecordTypeUsers, name: "hello.world", attributes: [
				kODAttributeTypeFirstName: ["Hello"], kODAttributeTypeLastName: ["World"],
				kODAttributeTypeFullName: ["Hello World"],
				kODAttributeTypePassword: ["toto"],
//				kODAttributeTypeMetaNodeLocation: ["/LDAPv3/127.0.0.1"],
//				kODAttributeTypeRecordName: ["hello.world"],
//				kODAttributeTypeMetaRecordName: ["uid=hello.world,cn=users,dc=office2,dc=happn,dc=private"],
//				kODAttributeTypeRecordType: [kODRecordTypeUsers],
			])
//			try print(node.record(withRecordType: kODRecordTypeUsers, name: "hello.world", attributes: nil))
		}
	}
	#else
	return context.container.future()
	#endif
	
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
}
