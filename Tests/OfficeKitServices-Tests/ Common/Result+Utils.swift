/*
 * Result+Utils.swift
 * CommonForOfficeKitServicesTests
 *
 * Created by François Lamboley on 2023/01/05.
 */

import Foundation



public extension Result {
	
	/* From OfficeKit2. */
	init(_ catching: () async throws -> Success) async where Failure == Error {
		do    {self = try await .success(catching())}
		catch {self =           .failure(error)}
	}
	
}
