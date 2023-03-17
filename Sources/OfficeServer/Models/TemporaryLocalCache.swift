/*
 * TemporaryLocalCache.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/03/17.
 */

import Foundation

import Vapor



public extension Application {
	
	var tempLocalCache_users: (keys: [String], values: [[String: String]])? {
		get {
			return locks.lock(for: TempLocalCacheUsersKey.self).withLock{
				storage[TempLocalCacheUsersKey.self]
			}
		}
		set {
			return locks.lock(for: TempLocalCacheUsersKey.self).withLock{
				storage[TempLocalCacheUsersKey.self] = newValue
			}
		}
	}
	
	private struct TempLocalCacheUsersKey: StorageKey, LockKey {
		typealias Value = (keys: [String], values: [[String: String]])
	}
	
}
