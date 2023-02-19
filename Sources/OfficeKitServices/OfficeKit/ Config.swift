/*
 *  Config.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import Logging



public enum OfficeKitOfficeConfig : Sendable {
	
	static public var logger: Logger? = Logger(label: "com.happn.officekit-services.officekit")
	
}

typealias Conf = OfficeKitOfficeConfig
