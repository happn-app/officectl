/*
 * Conf.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/16.
 */

import Foundation

import Logging



struct Conf : Decodable {
	
	var logLevel: Logger.Level?
	var environment: Environment?
	
	enum CodingKeys : String, CodingKey {
		case logLevel = "log_level"
		case environment
	}
	
}
