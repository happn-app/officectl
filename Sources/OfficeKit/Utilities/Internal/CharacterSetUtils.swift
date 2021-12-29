/*
 * CharacterSetUtils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2018/09/07.
 */

import Foundation



extension CharacterSet {
	
	static let asciiLowercaseLetters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz")
	static let asciiUppercaseLetters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
	static let asciiLetters = asciiLowercaseLetters.union(asciiUppercaseLetters)
	
	static let asciiNumbers = CharacterSet(charactersIn: "0123456789")
	
	static let asciiAlphanumerics = asciiLetters.union(asciiNumbers)
	
	static let hexadecimalCharacter = asciiNumbers.union(CharacterSet(charactersIn: "abcdefABCDEF"))
	
	static let ldapNumericoidCharset = asciiNumbers.union(CharacterSet(charactersIn: "."))
	static let ldapKeycharCharset = asciiAlphanumerics.union(CharacterSet(charactersIn: "-"))
	
}
