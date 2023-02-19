/*
 *  Config.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/03.
 */

import Foundation

import Logging



public enum OfficeKitConfig : Sendable {
	
	static public var logger: Logger? = Logger(label: "com.happn.officekit")
	
}

typealias Conf = OfficeKitConfig
