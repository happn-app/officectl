/*
 * RecordWrapper.swift
 * OpenDirectoryOffice
 *
 * Created by François Lamboley on 2023/01/04.
 */

import OpenDirectory
import Foundation



@ODActor
@propertyWrapper
internal final class ODObjectWrapper<ODObject> {
	
	var wrappedValue: ODObject?
	
	/* init can only be done with a nil value: otherwise it’d have to be an isolated init. */
	nonisolated init() {
		self.wrappedValue = nil
	}
	
	func perform<T : Sendable>(_ block: @Sendable (inout ODObject?) throws -> T) rethrows -> T {
		return try block(&wrappedValue)
	}
	
}
