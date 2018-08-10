/*
 * main.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import Vapor



do {try app().run()}
catch {
	print("Error creating or running the App."/* to stderr */)
	print("   error \(error) (domain \((error as NSError).domain), code \((error as NSError).code))"/* to stderr */)
	exit(Int32((error as NSError).code))
}
