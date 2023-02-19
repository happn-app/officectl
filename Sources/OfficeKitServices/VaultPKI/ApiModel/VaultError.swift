/*
 * VaultError.swift
 * VaultPKIOffice
 *
 * Created by François Lamboley on 2022/09/28.
 */

import Foundation


struct VaultError : Decodable {
	
	var errors: [String] /* I guess this only ever contains strings, but doc is not explicit about it. */
	
}
