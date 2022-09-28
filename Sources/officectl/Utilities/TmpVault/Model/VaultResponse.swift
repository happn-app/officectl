/*
 * VaultResponse.swift
 * officectl
 *
 * Created by François Lamboley on 2022/09/28.
 */

import Foundation



struct VaultResponse<ObjectType : Decodable> : Decodable {
	
	var data: ObjectType
	
}
