/*
 * MultiServicesPasswordReset.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/08/2019.
 */

import Foundation

import NIO
import ServiceKit



public typealias MultiServicesPasswordReset = MultiServicesItem<AnyDSPasswordResetPair?>
extension MultiServicesPasswordReset {
	
	public static func fetch(from dsuIdPair: AnyDSUIdPair, in services: Set<AnyUserDirectoryService>, using depServices: Services) async throws -> MultiServicesPasswordReset {
		let user = try await MultiServicesUser.fetch(from: dsuIdPair, in: services, using: depServices).get()
		return user.mapItems{ try $0.flatMap{ try $0.service.supportsPasswordChange ? AnyDSPasswordResetPair(dsuPair: $0, using: depServices) : nil } }
	}
	
	public var isExecuting: Bool {
		return itemsByService.reduce(false, { $0 || $1.value?.passwordReset.isExecuting ?? false })
	}
	
	public func start(newPass: String, weakeningMode: WeakeningMode, eventLoop: EventLoop) async throws -> [AnyUserDirectoryService: Result<Void, Error>] {
		guard !isExecuting else {throw OperationAlreadyInProgressError()}
		
		let futures = errorsAndItemsByService.map{ serviceIdAndResetPairResult -> (AnyUserDirectoryService, EventLoopFuture<Void>) in
			let (service, resetPairResult) = serviceIdAndResetPairResult
			
			switch resetPairResult {
			case .success(nil):            return (service, eventLoop.makeSucceededFuture(()))
			case .success(let resetPair?): return (service, resetPair.passwordReset.start(parameters: newPass, weakeningMode: weakeningMode, eventLoop: eventLoop))
			case .failure(let error):      return (service, eventLoop.makeFailedFuture(error))
			}
		}
		
		return try await EventLoopFuture<Void>.waitAll(futures, eventLoop: eventLoop)
		.flatMapThrowing{ try $0.group(by: { $0.0 }, mappingValues: { $0.1 }) }
		.get()
	}
	
}
