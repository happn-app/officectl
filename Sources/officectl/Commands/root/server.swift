/*
 * backup.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit



func server(flags f: Flags, arguments args: [String], context: CommandContext) throws -> EventLoopFuture<Void> {
	throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Please choose a server command"])
}
