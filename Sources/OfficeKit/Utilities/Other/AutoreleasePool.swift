/*
 * AutoreleasePool.swift
 * OfficeKit
 *
 * Created by François Lamboley on 10/08/2018.
 */

import Foundation



/* Straight from SwiftNIO */
func withAutoReleasePool<T>(_ execute: () throws -> T) rethrows -> T {
	#if !os(Linux)
		return try autoreleasepool{
			try execute()
		}
	#else
		return try execute()
	#endif
}
