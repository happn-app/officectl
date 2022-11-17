/*
 * CommonProperties.swift
 * HappnOfficeServiceCommonProperties
 *
 * Created by François Lamboley on 2022/11/15.
 */

import Foundation

import OfficeKit2



/* This is the union of all the non-standard properties used by all the happn services.
 * Not all services support all these properties, but at least one service support each properties. */
public extension UserProperty {
	
	static let gender    = UserProperty(rawValue: "gender")
	static let birthdate = UserProperty(rawValue: "birthdate")
	
}


public enum Gender : String, Sendable, Codable, RawRepresentable {
	
	case male
	case female
	
}
