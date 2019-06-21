/*
 * GitHubService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/06/2019.
 */

import Foundation

import Async
import SemiSingleton



public class GitHubService : DirectoryService {
	
	enum Error : Swift.Error {
		
		case notSupported
		
	}
	
	public static let id = "internal_github"
	
	public typealias UserIdType = String
	
	public let supportsPasswordChange = false
	
	public let serviceId: String
	public let serviceName: String
	public let asyncConfig: AsyncConfig
	public let gitHubConfig: GitHubServiceConfig
	public let semiSingletonStore: SemiSingletonStore
	
	public let gitHubConnector: GitHubJWTConnector
	
	public init(id: String, name: String, googleConfig config: GitHubServiceConfig, semiSingletonStore sms: SemiSingletonStore, asyncConfig ac: AsyncConfig) throws {
		serviceId = id
		asyncConfig = ac
		serviceName = name
		gitHubConfig = config
		semiSingletonStore = sms
		
		gitHubConnector = try sms.semiSingleton(forKey: config.connectorSettings)
	}
	
	public func changePasswordAction(for user: String) throws -> Action<String, String, Void> {
		throw Error.notSupported
	}
	
	public func existingUserId<T>(from userId: T.UserIdType, in service: T) -> Future<String?> where T : DirectoryService {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}

}
