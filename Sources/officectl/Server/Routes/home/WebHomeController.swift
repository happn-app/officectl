/*
 * WebHomeController.swift
 * officectl
 *
 * Created by François Lamboley on 18/04/2020.
 */

import Foundation

import NIO
import Vapor



struct WebHomeController {
	
	func showHome(_ req: Request) async throws -> View {
		return try await req.view.render("Home")
	}
	
}
