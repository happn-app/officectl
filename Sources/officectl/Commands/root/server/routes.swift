/*
 * routes.swift
 * officectl
 *
 * Created by François Lamboley on 26/07/2018.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit



func serverRoutes(flags f: Flags, arguments args: [String], context: CommandContext) throws -> EventLoopFuture<Void> {
	return try RoutesCommand(router: context.container.make()).run(using: context)
}
