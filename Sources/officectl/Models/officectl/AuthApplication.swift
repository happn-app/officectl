/*
 * AuthApplication.swift
 * officectl
 *
 * Created by François Lamboley on 2021/12/29.
 */

import Foundation

import OfficeModel
import Vapor



enum AuthApplication : String, Authenticatable {
	
	case officectl
	case OfficeApp
	
	func matchesSecret(_ secret: String?) -> Bool {
		return secret?.isEmpty ?? true
	}
	
	var authorizedScopes: Set<AuthScope> {
		return Set(AuthScope.allCases)
	}
	
}
