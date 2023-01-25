/*
 * configure.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/16.
 */

import Foundation

import Metrics
import Prometheus
import QueuesRedisDriver
import Vapor



public func configure(_ app: Application) throws {
	/* Bootstraps (except the Logger, which is done before). */
	MetricsSystem.bootstrap(PrometheusMetricsFactory(client: PrometheusClient()))
	
	/* Configure queues. */
//	try app.queues.use(.redis(url: Environment.get("REDIS_URL") ?? "redis://127.0.0.1:6379"))
	
	/* Setup the routes. */
	try routes(app)
}
