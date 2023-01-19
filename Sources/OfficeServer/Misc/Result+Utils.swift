/*
 * Result+Utils.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/19.
 */

import Foundation



extension Result {
	
	init(_ catching: () async throws -> Success) async where Failure == Error {
		do    {self = try await .success(catching())}
		catch {self =           .failure(error)}
	}
	
	var isSuccessful: Bool {
		switch self {
			case .success: return true
			case .failure: return false
		}
	}
	
}
