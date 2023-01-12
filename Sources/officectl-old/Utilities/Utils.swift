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

func groupUsersByID<S : Sequence>(from users: S) throws -> [AnyID: AnyDirectoryUser] where S.Element == AnyDirectoryUser {
	return try users.group(by: { $0.userID })
}

func normalizeCertificateID(_ id: String) -> String {
	let characterSet = CharacterSet(charactersIn: "0123456789abcdef")
	var preresult = id.lowercased().drop{ $0 == "0" }
	preresult.removeAll{
		let scalars = $0.unicodeScalars
		guard let scalar = scalars.onlyElement else {return true}
		return !characterSet.contains(scalar)
	}
	return String(preresult)
}

extension Dictionary {
	
	func mapKeys<T : Hashable>(_ transform: (Key) throws -> T) rethrows -> [T: Value] {
		return try Dictionary<T, Value>(uniqueKeysWithValues: map{ try (transform($0.key), $0.value) })
	}
	
}
