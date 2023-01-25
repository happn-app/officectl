/*
 * UpdateCAMetricsJob.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation

import Queues



struct UpdateCAMetricsJob : AsyncScheduledJob {
	
	func run(context: Queues.QueueContext) async throws {
		context.application.logger.debug("TODO: Update CA Metrics")
	}
	
}
