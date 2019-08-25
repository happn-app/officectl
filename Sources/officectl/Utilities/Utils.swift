/*
 * Utils.swift
 * officectl
 *
 * Created by François Lamboley on 2019/7/13.
 */

import Foundation

import OfficeKit



func generateRandomPassword(length: Int = 13) -> String {
	let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	return String((0..<length).map{ _ in chars.randomElement()! })
}

func groupUsersById<S : Sequence>(from users: S) throws -> [AnyHashable: AnyDirectoryUser] where S.Element == AnyDirectoryUser {
	return try users.group(by: { $0.userId })
}

extension Dictionary {
	
	func mapKeys<T : Hashable>(_ transform: (Key) throws -> T) rethrows -> [T: Value] {
		return try Dictionary<T, Value>(uniqueKeysWithValues: map{ try (transform($0.key), $0.value) })
	}
	
}
