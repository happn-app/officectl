/*
 * DeleteUserRequestQuery.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/22.
 * 
 */

import Foundation



internal struct DeleteUserRequestQuery : Sendable, Encodable {
	
	var toDelete = "true"
	
	private enum CodingKeys : String, CodingKey {
		case toDelete = "to_delete"
	}
	
}
