/*
 * ResetPasswordAction.swift
 * OfficeKit
 *
 * Created by François Lamboley on 27/08/2018.
 */

import Foundation

import SemiSingleton
import Vapor



public class ResetPasswordAction : SemiSingleton {
	
	public typealias SemiSingletonKey = User
	public typealias SemiSingletonAdditionalInitInfo = Void
	
	public let user: User
	public private(set) var newPassword: String?
	
	public private(set) var ldapResetResult: Future<Void>?
	public private(set) var googleResetResult: Future<Void>?
	
	public var allResults: [Future<Void>] {
		return [ldapResetResult, googleResetResult].compactMap{ $0 }
	}
	
	public var isExecuting: Bool {
		return syncQueue.sync{ executingWitness != nil }
	}
	
	/* Sub-actions */
	public var resetLDAPPasswordAction: ResetLDAPPasswordAction
	public var resetGooglePasswordAction: ResetGooglePasswordAction
	
	public required init(key u: User, additionalInfo: Void, store: SemiSingletonStore) {
		user = u
		newPassword = nil
		
		syncQueue = DispatchQueue(label: "Reset Password Sync Queue for \(user.id.stringValue)", attributes: [/*serial*/])
		
		resetLDAPPasswordAction = store.semiSingleton(forKey: u)
		resetGooglePasswordAction = store.semiSingleton(forKey: u)
	}
	
	public func start(newPassword p: String, container: Container) throws -> Future<Void> {
		try syncQueue.sync{
			guard self.executingWitness == nil else {throw OperationAlreadyInProgressError()}
			self.executingWitness = self
		}
		
		let eventLoop = try container.make(AsyncConfig.self).eventLoop
		let promise: EventLoopPromise<Void> = eventLoop.newPromise()
		
		newPassword = p
		
		/* Start LDAP reset */
		startResetForOneService(
			eventLoop: eventLoop,
			{ try resetLDAPPasswordAction.start(newPassword: p, container: container) }
		)
		
		return promise.futureResult
	}
	
	private let syncQueue: DispatchQueue
	private var executingWitness: ResetPasswordAction?
	
	private func startResetForOneService(eventLoop: EventLoop, _ startResetBlock: () throws -> Future<Void>) -> Future<Void> {
		do {
			let f = try startResetBlock()
			f.addAwaiter{ result in
				switch result {
				case .error(let error): ()
				case .success: ()
				}
			}
			return f
		} catch {
			return eventLoop.newFailedFuture(error: error)
		}
	}
	
}
