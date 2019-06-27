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
	
	public let supportsPasswordChange = false
	
	public let serviceConfig: GitHubServiceConfig
	
	public init(config: GitHubServiceConfig, semiSingletonStore sms: SemiSingletonStore, asyncConfig ac: AsyncConfig) throws {
		serviceConfig = config
		
		asyncConfig = ac
		semiSingletonStore = sms
		
		gitHubConnector = try sms.semiSingleton(forKey: config.connectorSettings)
	}
	
	public func existingUserId(from email: Email) -> some Future<Hashable?> {
		return asyncConfig.eventLoop.newFailedFuture(error: Error.notSupported)
	}
	
	public func existingUserId(from userId: TaggedId, in service: DirectoryService) -> some EventLoopFuture<Hashable?> {
		return asyncConfig.eventLoop.newFailedFuture(error: NotImplementedError())
	}
	
	public func changePasswordAction(for user: TaggedId) throws -> some Action<Hashable, String, Void> {
		throw Error.notSupported
		return Action<Int, String, Void>(subject: 0)
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let asyncConfig: AsyncConfig
	private let semiSingletonStore: SemiSingletonStore
	
	private let gitHubConnector: GitHubJWTConnector
	
}
