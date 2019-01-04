/*
 * HasResult.swift
 * OfficeKit
 *
 * Created by François Lamboley on 02/01/2019.
 */

import Foundation



public protocol HasResult {
	
	associatedtype ResultType
	
	func resultOrThrow() throws -> ResultType
	
}

public extension HasResult {
	
	var result: ResultType? {
		do    {return try resultOrThrow()}
		catch {return nil}
	}
	
	var resultError: Error? {
		do    {_ = try resultOrThrow(); return nil}
		catch {return error}
	}
	
}
