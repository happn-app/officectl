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
		let user = try await MultiServicesUser.fetch(from: dsuIdPair, in: services, using: depServices)
		return user.mapItems{ try $0.flatMap{ try $0.service.supportsPasswordChange ? AnyDSPasswordResetPair(dsuPair: $0, using: depServices) : nil } }
	}
	
	public var isExecuting: Bool {
		return itemsByService.reduce(false, { $0 || $1.value?.passwordReset.isExecuting ?? false })
	}
	
	public func start(newPass: String, weakeningMode: WeakeningMode) async throws -> [AnyUserDirectoryService: Result<Void, Error>] {
		guard !isExecuting else {throw OperationAlreadyInProgressError()}
		
		return await withTaskGroup(
			of: (AnyUserDirectoryService, Result<Void, Error>).self,
			returning: [AnyUserDirectoryService: Result<Void, Error>].self,
			body: { group in
				for (service, resetPairResult) in errorsAndItemsByService {
					group.addTask{
						return await (service, Result<Void, Error>{
							switch resetPairResult {
								case .success(nil):            return ()
								case .success(let resetPair?): return try await resetPair.passwordReset.start(parameters: newPass, weakeningMode: weakeningMode)
								case .failure(let error):      throw error
							}
						})
					}
				}
				
				var ret = [AnyUserDirectoryService: Result<Void, Error>]()
				while let (service, curRes) = await group.next() {
					assert(ret[service] == nil)
					ret[service] = curRes
				}
				return ret
			}
		)
	}
	
}
