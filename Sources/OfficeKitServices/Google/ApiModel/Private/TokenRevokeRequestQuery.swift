/*
 * TokenRevokeRequestQuery.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/11/24.
 */

import Foundation



struct TokenRevokeRequestQuery : Sendable, Encodable {
	
	let token: String
	
}
