/*
 * stderr.swift
 * ghapp
 *
 * Created by François Lamboley on 2/11/17.
 *
 */

import Foundation



class StandardErrorOutputStream: TextOutputStream {
	
	func write(_ string: String) {
		let stderr = FileHandle.standardError
		stderr.write(string.data(using: String.Encoding.utf8)!)
	}
	
}

var mx_stderr = StandardErrorOutputStream()
