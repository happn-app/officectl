/*
 * WebHomeController.swift
 * officectl
 *
 * Created by François Lamboley on 2020/04/18.
 */

import Foundation

import NIO
import Vapor



struct WebHomeController {
	
	func showHome(_ req: Request) async throws -> View {
		return try await req.view.render("Home")
	}
	
}
