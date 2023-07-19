/*
 * Email+ArgumentParser.swift
 * officectl
 *
 * Created by François Lamboley on 2020/06/12.
 */

import Foundation

import ArgumentParser
import Email
import OfficeKit



extension Email : ExpressibleByArgument {
	
	public init?(argument: String) {
		self.init(rawValue: argument)
	}
	
}
