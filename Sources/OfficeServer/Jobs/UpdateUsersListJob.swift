/*
 * UpdateUsersListJob.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation

import Metrics
import Queues

import OfficeKit
import VaultPKIOffice



public struct UpdateUsersListJob : AsyncScheduledJob {
	
	public init() {
	}
	
	public func run(context: Queues.QueueContext) async throws {
		struct NotImplemented : Error {}
		throw NotImplemented()
	}
	
}
