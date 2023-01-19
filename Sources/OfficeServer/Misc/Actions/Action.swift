/*
 * Action.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/19.
 */

import Foundation



public protocol ActionProtocol : Sendable {
	
	associatedtype Subject    : Sendable
	associatedtype Parameters : Sendable
	associatedtype Results    : Sendable
	
	init(subject: Subject)
	func execute(parameters: Parameters) async throws -> Results
	
}
