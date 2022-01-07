/*
 * MultiServicesPasswordReset.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/08/24.
 */

import Foundation

import CollectionConcurrencyKit
import NIO
import ServiceKit



public typealias MultiServicesPasswordReset = MultiServicesItem<AnyDSPasswordResetPair?>
extension MultiServicesPasswordReset {
	
	public static func fetch(from dsuIDPair: AnyDSUIDPair, in services: Set<AnyUserDirectoryService>, using depServices: Services) async throws -> MultiServicesPasswordReset {
		let user = try await MultiServicesUser.fetch(from: dsuIDPair, in: services, using: depServices)
		return user.mapItems{ try $0.flatMap{ try AnyDSPasswordResetPair(dsuPair: $0, using: depServices) } }
	}
	
	public var isExecuting: Bool {
		return itemsByService.reduce(false, { $0 || $1.value?.passwordReset.isExecuting ?? false })
	}
	
	public func start(newPass: String, weakeningMode: WeakeningMode) async throws -> [AnyUserDirectoryService: Result<Void, Error>] {
		guard !isExecuting else {throw OperationAlreadyInProgressError()}
		
		return await errorsAndItemsByService.concurrentMapValues{ resetPairResult in
			return await Result<Void, Error>{
				switch resetPairResult {
					case .success(nil):            return ()
					case .success(let resetPair?): return try await resetPair.passwordReset.start(parameters: newPass, weakeningMode: weakeningMode)
					case .failure(let error):      throw error
				}
			}
		}
	}
	
}
