/*
 * Role.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/30.
 */

import Foundation



enum Role : String, Sendable, Codable {
	
	case admin
	case directMember = "direct_member"
	case billingManager = "billing_manager"
	
}
