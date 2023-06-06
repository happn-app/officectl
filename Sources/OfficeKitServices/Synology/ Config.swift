/*
 *  Config.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation

import Logging



public enum SynologyOfficeConfig : Sendable {
	
	static public var logger: Logger? = Logger(label: "com.happn.officekit-services.synology")
	
}

typealias Conf = SynologyOfficeConfig
