/*
 * LDAPInitActor.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation



@globalActor
enum LDAPInitActor {
	actor Actor {}
	static let shared: Actor = .init()
}
