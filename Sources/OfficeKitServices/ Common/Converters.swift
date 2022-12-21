/*
 * Converters.swift
 * CommonOfficePropertiesFromHappn
 *
 * Created by François Lamboley on 2022/12/21.
 */

import Foundation

import OfficeKit2



public extension Converters {
	
	static func convertObjectToGender(_ obj: Any?) -> Gender? {
		guard let obj = unwrapJSONIfNeeded(obj) else {
			return nil
		}
		
		switch obj {
			case let gender as Gender: return gender
			default:
				guard let str = convertObjectToString(obj) else {
					return nil
				}
				return Gender(rawValue: str)
		}
	}
	
}
