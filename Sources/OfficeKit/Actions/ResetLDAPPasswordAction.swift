/*
 * ResetLDAPPasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 13/11/2018.
 */

import Foundation

import SemiSingleton
import Vapor



public class ResetLDAPPasswordAction : SemiSingleton {
	
	public typealias SemiSingletonKey = User
	public typealias SemiSingletonAdditionalInitInfo = Void
	
	public let user: User
	public private(set) var newPassword: String?
	
	public var isExecuting: Bool {
		return syncQueue.sync{ executingWitness != nil }
	}
	
	public required init(key u: User, additionalInfo: Void, store: SemiSingletonStore) {
		user = u
		newPassword = nil
		
		syncQueue = DispatchQueue(label: "Reset LDAP Password Sync Queue for \(user.id.stringValue)", attributes: [/*serial*/])
	}
	
	public func start(newPassword p: String, container: Container) throws -> Future<Void> {
		try syncQueue.sync{
			guard self.executingWitness == nil else {throw OperationAlreadyInProgressError()}
			self.executingWitness = self
		}
		
		let eventLoop = try container.make(AsyncConfig.self).eventLoop
		let promise: EventLoopPromise<Void> = eventLoop.newPromise()
		
		newPassword = p
		
		return promise.futureResult
	}
	
	private let syncQueue: DispatchQueue
	private var executingWitness: ResetLDAPPasswordAction?
	
}
