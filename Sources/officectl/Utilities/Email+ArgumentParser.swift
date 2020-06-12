/*
 * Email+ArgumentParser.swift
 * officectl
 *
 * Created by François Lamboley on 12/06/2020.
 */

import Foundation

import ArgumentParser
import OfficeKit



extension Email : ExpressibleByArgument {
	
	public init?(argument: String) {
		self.init(string: argument)
	}
	
}
