/*
 * setup_routes.swift
 * officectl
 *
 * Created by François Lamboley on 06/08/2018.
 */

import Foundation

import Vapor



func setup_routes(_ router: Router) throws {
	/* Basic "Hello, world!" example */
	router.get("hello") { req in
		return "Hello, world!"
	}
	
	let resetPassPath: [PathComponent] = [.constant("reset-password"), .parameter("userId")]
//	router.get(resetPassPath, use: <#T##(Request) throws -> ResponseEncodable#>)
//	// Example of configuring a controller
//	let todoController = TodoController()
//	router.get("todos", use: todoController.index)
//	router.post("todos", use: todoController.create)
//	router.delete("todos", Todo.parameter, use: todoController.delete)
}
