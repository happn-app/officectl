/*
 * users.swift
 * officectl
 *
 * Created by François Lamboley on 20/08/2018.
 */

import Foundation

import Guaka
import Vapor

import OfficeKit



func users(flags f: Flags, arguments args: [String], context: CommandContext) throws -> Future<Void> {
	throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "subcommand is required"])
}
