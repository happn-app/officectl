/*
 * Logger.Level+ExpressibleByArgument.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/12.
 */

import Foundation

import ArgumentParser
import Email



extension Email : ExpressibleByArgument {
	
	public init?(argument: String) {
		self.init(rawValue: argument)
	}
	
}
