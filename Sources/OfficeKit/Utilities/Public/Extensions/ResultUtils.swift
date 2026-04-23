/*
 * ResultUtils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 02/04/2019.
 */

import Foundation

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

public func RError<T>(domain: String, code: Int, userInfo: [String: Any]?) -> Result<T, Error> {
	return .failure(NSError(domain: domain, code: code, userInfo: userInfo))
}
