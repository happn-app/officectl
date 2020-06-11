/*
 * ServerOptions.swift
 * officectl
 *
 * Created by François Lamboley on 11/06/2020.
 */

import Foundation

import ArgumentParser



struct ServerOptions : ParsableArguments {
	
	/* Note: We do **not** provide the bind option because I don’t like it
	 *       (because of IPv6; Vapor simply ignores there are hostname that can
	 *       contain semicolons; I don’t want to ignore that but also want to be
	 *       as compatible as possible with Vapor’s options, so the best solution
	 *       is to simply not provide the bind option).
	 *       Also, not providing the bind option simplifies the hostname and port
	 *       selection! */
	
	@Option(name: [.customShort("H"), .long], help: "The hostname the server will run on. Defaults to localhost.")
	var hostname: String?
	
	@Option(name: .shortAndLong, help: "The port the server will run on. Defaults to 8080.")
	var port: Int?
	
	@Option(name: .long, help: "The secret to use for generating the JWT tokens.")
	var jwtSecret: String?
	
}
