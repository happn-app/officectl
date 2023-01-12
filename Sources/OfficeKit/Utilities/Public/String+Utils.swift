/*
 * String+Utils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/12/23.
 */

import Foundation



public extension String {
	
	static func generatePassword(
		allowedChars: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789=+_-$!@#%^&*(){}[]'\\\";:/?.>,<§",
		length: Int = 64
	) -> String {
		assert(length > 0)
		assert(!allowedChars.isEmpty)
		return String((0..<length).map{ _ in allowedChars.randomElement()! })
	}
	
}
