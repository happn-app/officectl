/*
 * MetricsController.swift
 * officectl
 *
 * Created by François Lamboley on 2022/09/26.
 */

import Foundation

import Metrics
import Prometheus
import Vapor



class MetricsController {
	
	func get(_ req: Request) async throws -> String {
		return try await MetricsSystem.prometheus().collect()
	}
	
}
