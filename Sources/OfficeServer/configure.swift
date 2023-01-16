/*
 * configure.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/16.
 */

import Foundation

import Metrics
import Prometheus
import Vapor



public func configure(_ app: Application) throws {
	MetricsSystem.bootstrap(PrometheusMetricsFactory(client: PrometheusClient()))
	
	try routes(app)
}
