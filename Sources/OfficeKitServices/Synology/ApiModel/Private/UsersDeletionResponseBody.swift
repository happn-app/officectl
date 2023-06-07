/*
 * UsersDeletionResponseBody.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/07.
 */

import Foundation



struct UsersDeletionResponseBody : Sendable, Decodable {
	
	/* The sucessful deletion response for a single user is an “errors” array that contains a single int 3102.
	 * Not sure what’s going on here, but rn idc. */
	var errors: [Int]
	
}
