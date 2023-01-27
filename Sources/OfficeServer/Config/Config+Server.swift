/*
 * Config+Server.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation

import Metrics
import Prometheus
import Queues
import Vapor



public extension Conf {
	
	static func setupServer(_ app: Application, scheduledJobs: [(AsyncScheduledJob, (ScheduleBuilder) -> Void)] = []) throws {
		scheduleServerJobs(scheduledJobs, with: app)
		
		try setupRoutes(app)
		try app.queues.startScheduledJobs()
	}
	
	static func setupRoutes(_ app: Application) throws {
		app.routes.get("_internal", "metrics", use: { _ in try await MetricsSystem.prometheus().collect() })
		
		let apiRoute = app.grouped("api", "v2")
//		try app.register(collection: AuthController())
		try apiRoute.register(collection: ServicesController())
		try apiRoute.register(collection: UsersController())
	}
	
	
	internal static func scheduleServerJobs(_ jobs: [(AsyncScheduledJob, (ScheduleBuilder) -> Void)], with app: Application) {
		for (job, buildSchedule) in jobs {
			buildSchedule(app.queues.schedule(job))
		}
		/* We also run the jobs directly on server launch.
		 * Not sure whether it’s a good idea though. */
		Task{ [jobs] in
			for (job, _) in jobs {
				_ = try? await job.run(context: .init(queueName: .default, configuration: .init(), application: app, logger: app.logger, on: app.eventLoopGroup.next()))
			}
		}
	}
	
}
