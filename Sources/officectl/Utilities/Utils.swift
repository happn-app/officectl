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
	return try groupCollection(users, by: { $0.userId })
}

func groupCollection<S : Sequence, IdentifierType : Hashable>(_ collection: S, by keyForValue: (S.Element) -> IdentifierType) throws -> [IdentifierType: S.Element] {
	let grouped = Dictionary(grouping: collection, by: keyForValue)
	return try grouped.mapValues{ groupedElement in
		guard let element = groupedElement.onlyElement else {
			throw InternalError(message: "Invalid sequence which contains at least two elements with the same id.")
		}
		return element
	}
}
