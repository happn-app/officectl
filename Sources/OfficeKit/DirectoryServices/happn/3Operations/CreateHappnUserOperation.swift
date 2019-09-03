/*
 * CreateHappnUserOperation.swift
 * OfficeKit
 *
 * Created by François Lamboley on 02/09/2019.
 */

import Foundation

import RetryingOperation



public final class CreateHappnUserOperation : RetryingOperation, HasResult {
	
	public typealias ResultType = HappnUser
	
	public private(set) var result = Result<HappnUser, Error>.failure(OperationIsNotFinishedError())
	
	// 1.
	// POST /api/users/
	// Data: {"login":"test@happn.fr","first_name":"Test","last_name":"officectl","gender":"male","marital":"HCRelationshipSingle","birth_date":"2000-9-2","password":"toto","type":"CLIENT"}
	// Response: User
	//
	// 2.
	// POST /api/administrators/
	// Data: x-www-form-urlencoded
	//    - _action: grant
	//    - password: ...
	//    - user_id: ...
	// Response: null (in a standard response)
	//
	// 3.
	// POST /api/user-acls
	// Data: x-www-form-urlencoded
	//    - permissions: ...
	//    - user_id: ...
	// Response: null (in a standard response)
	
}
