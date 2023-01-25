/*
 * Config+Bootstrap.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation

import Logging
import Metrics
import Prometheus
import Queues
import Vapor



public extension Conf {
	
	static func bootstrap(_ app: Application, skipLogger: Bool = false) throws {
		if !skipLogger {
			try LoggingSystem.bootstrap(from: &app.environment)
		}
		
		MetricsSystem.bootstrap(PrometheusMetricsFactory(client: PrometheusClient()))
	}
	
}
