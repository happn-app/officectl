/*
 * ApiError.swift
 * officectl
 *
 * Created by François Lamboley on 21/02/2019.
 */

import Foundation

import LegibleError
import Vapor



struct ApiError : Codable {
	
	var code: Int
	var domain: String
	var message: String
	
	init(code c: Int, domain d: String, message m: String) {
		code = c
		domain = d
		message = m
	}
	
	init(error: Error, environment: Environment) {
		/* Got base from ErrorMiddleWare */
		let theCode: Int
		let reason: String
		
		switch error {
		case let abort as AbortError:
			/* This is an abort error, we should use its status, reason, and
			 * headers */
			reason = abort.reason
			theCode = Int(abort.status.code)
			
		default:
			/* Not an abort error, and not debuggable or in dev mode, just deliver
			 * a generic 500 to avoid exposing any sensitive error info. */
			reason = (environment.isRelease ? "Something went wrong." : error.legibleLocalizedDescription)
			theCode = (error as NSError).code
		}
		
		code = theCode
		domain = (error as NSError).domain
		message = reason
	}
	
}
