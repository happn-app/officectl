/*
 * StderrStream.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/24.
 */

import Foundation
//#if canImport(System)
//import System
//#else
//import SystemPackage
//#endif



struct StderrStream : TextOutputStream {
	
	mutating func write(_ string: String) {
//		try! FileDescriptor.standardError.writeAll(Data(string.utf8))
		try! FileHandle.standardError.write(contentsOf: Data(string.utf8))
	}
	
}
