/*
 * MultiServicesPasswordReset.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/08/2019.
 */

import Foundation

import Service



public typealias MultiServicesPasswordReset = MultiServicesItem<AnyDSPasswordResetPair?>
extension MultiServicesPasswordReset {
	
	public static func fetch(from dsuIdPair: AnyDSUIdPair, in services: Set<AnyDirectoryService>, on container: Container) throws -> EventLoopFuture<MultiServicesPasswordReset> {
		return try MultiServicesUser.fetch(from: dsuIdPair, in: services, on: container)
		.map{ user in user.mapItems{ try $0.flatMap{ try $0.service.supportsPasswordChange ? AnyDSPasswordResetPair(dsuPair: $0, on: container) : nil } } }
	}
	
	public var isExecuting: Bool {
		return itemsByService.reduce(false, { $0 || $1.value?.passwordReset.isExecuting ?? false })
	}
	
	public func start(newPass: String, weakeningMode: WeakeningMode, eventLoop: EventLoop) throws -> EventLoopFuture<[AnyDirectoryService: Result<Void, Error>]> {
		guard !isExecuting else {throw OperationAlreadyInProgressError()}
		
		let futures = errorsAndItemsByService.map{ serviceIdAndResetPairResult -> (AnyDirectoryService, Future<Void>) in
			let (service, resetPairResult) = serviceIdAndResetPairResult
			
			switch resetPairResult {
			case .success(nil):            return (service, eventLoop.newSucceededFuture(result: ()))
			case .success(let resetPair?): return (service, resetPair.passwordReset.start(parameters: newPass, weakeningMode: weakeningMode, eventLoop: eventLoop))
			case .failure(let error):      return (service, eventLoop.future(error: error))
			}
		}
		
		return Future.waitAll(futures, eventLoop: eventLoop)
		.map{ try $0.group(by: { $0.0 }, mappingValues: { $0.1 }) }
	}
	
}
