/*
 * Result+Utils.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/24.
 */

import Foundation



extension Result {
	
	init(_ catching: () async throws -> Success) async where Failure == Error {
		do    {self = try await .success(catching())}
		catch {self =           .failure(error)}
	}
	
	var failure: Failure? {
		switch self {
			case .success:        return nil
			case .failure(let f): return f
		}
	}
	
	var success: Success? {
		switch self {
			case .failure:        return nil
			case .success(let s): return s
		}
	}
	
}
