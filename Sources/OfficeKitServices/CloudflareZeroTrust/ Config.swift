/*
 *  Config.swift
 * CloudflareZeroTrustOffice
 *
 * Created by François Lamboley on 2023/07/27.
 */

import Foundation

import Logging



public enum CloudflareZeroTrustOfficeConfig : Sendable {
	
	static public var logger: Logger? = Logger(label: "com.happn.officekit-services.cloudflare-zerotrust")
	
}

typealias Conf = CloudflareZeroTrustOfficeConfig
