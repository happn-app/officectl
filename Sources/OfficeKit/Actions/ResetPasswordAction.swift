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
	
	public enum Error : Swift.Error {
		
		case operationIsAlreadyExecuting
		
	}
	
	public typealias SemiSingletonKey = HappnUser
	
	public let user: HappnUser
	public private(set) var newPassword: String?
	
	public var isExecuting: Bool {
		return q.sync{ _isExecuting }
	}
	
	public required init(key: HappnUser) {
		user = key
		newPassword = nil
		
		q = DispatchQueue(label: "Reset Password Queue for \(user.email.stringValue)", attributes: [/*serial*/])
	}
	
	public func start(oldPassword: String, newPassword: String, container: Container) throws -> EventLoopFuture<Void> {
		try q.sync{
			guard !self._isExecuting else {throw Error.operationIsAlreadyExecuting}
			self._isExecuting = true
		}
		
		/* Let’s check the given old password */
		return try user.checkLDAPPassword(container: container, checkedPassword: oldPassword)
	}
	
	private let q: DispatchQueue
	
	private var _isExecuting = false
	
}
