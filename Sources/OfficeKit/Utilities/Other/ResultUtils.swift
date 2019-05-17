/*
 * ResultUtils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 02/04/2019.
 */

import Foundation

import AsyncOperationResult



extension Result {
	
	public var successValue: Success? {
		switch self {
		case .success(let s): return s
		case _:               return nil
		}
	}
	
	public var failureValue: Failure? {
		switch self {
		case .failure(let e): return e
		case _:               return nil
		}
	}
	
	public var isSuccessful: Bool {
		switch self {
		case .success: return true
		case .failure: return false
		}
	}
	
}

extension Result where Failure == Error {
	
	var asyncOperationResult: AsyncOperationResult<Success> {
		switch self {
		case .success(let success): return .success(success)
		case .failure(let failure): return .error(failure)
		}
	}
	
}

extension AsyncOperationResult {
	
	var result: Result<T, Error> {
		switch self {
		case .success(let success): return .success(success)
		case .error(let error):     return .failure(error)
		}
	}
	
}

public func RError<T>(domain: String, code: Int, userInfo: [String: Any]?) -> Result<T, Error> {
	return .failure(NSError(domain: domain, code: code, userInfo: userInfo))
}
