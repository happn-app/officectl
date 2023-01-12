/*
 * Result+Utils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/25.
 */

import Foundation



extension Result {
	
	init(_ catching: () async throws -> Success) async where Failure == Error {
		do    {self = try await .success(catching())}
		catch {self =           .failure(error)}
	}
	
	var successValue: Success? {
		switch self {
			case .success(let s): return s
			case _:               return nil
		}
	}
	
	var failureValue: Failure? {
		switch self {
			case .failure(let e): return e
			case _:               return nil
		}
	}
	
	var isSuccessful: Bool {
		switch self {
			case .success: return true
			case .failure: return false
		}
	}
	
}
