/*
 * Config+Queues.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation

//import QueuesRedisDriver
import Vapor



public extension Conf {
	
	static func setupQueues(_ app: Application) throws {
		/* Configure queues.
		 * In our case we do not use queues, but if we did, here’s how we would setup it. */
//		try app.queues.use(.redis(url: Environment.get("REDIS_URL") ?? "redis://127.0.0.1:6379"))
	}
	
}
