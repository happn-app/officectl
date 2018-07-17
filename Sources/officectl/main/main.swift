/*
 * main.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation



func run() {
	let rootCommand = configure()
	rootCommand.execute()
}

run()
