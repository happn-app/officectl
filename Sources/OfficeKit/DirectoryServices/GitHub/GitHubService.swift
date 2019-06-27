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
	
	public typealias UserIdType = String
	
	public let supportsPasswordChange = false
	public let serviceConfig: GitHubServiceConfig
	
	public init(config: GitHubServiceConfig, semiSingletonStore sms: SemiSingletonStore, asyncConfig ac: AsyncConfig) throws {
		serviceConfig = config
		
		asyncConfig = ac
		semiSingletonStore = sms
		
		gitHubConnector = try sms.semiSingleton(forKey: config.connectorSettings)
	}
	
	public func existingUserId(from email: Email) -> Future<String?> {
		return asyncConfig.eventLoop.newFailedFuture(error: Error.notSupported)
	}
	
	public func existingUserId<T>(from userId: T.UserIdType, in service: T) -> Future<String?> where T : DirectoryService {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public func changePasswordAction(for user: String) throws -> Action<String, String, Void> {
		throw Error.notSupported
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let asyncConfig: AsyncConfig
	private let semiSingletonStore: SemiSingletonStore
	
	private let gitHubConnector: GitHubJWTConnector
	
}
