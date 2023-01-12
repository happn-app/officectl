/*
 * ApiError+Conveniences.swift
 * officectl
 *
 * Created by François Lamboley on 2021/12/30.
 */

import Foundation

import Vapor

import OfficeModel



extension ApiError {
	
	init(error: Error, environment: Environment) {
		/* Got base from ErrorMiddleWare */
		let theCode: Int
		let reason: String
		
		switch error {
			case let abort as AbortError:
				/* This is an abort error, we should use its status, reason, and headers */
				reason = abort.reason
				theCode = Int(abort.status.code)
				
			default:
				/* Not an abort error, and not debuggable or in dev mode, just deliver a generic 500 to avoid exposing any sensitive error info. */
				reason = (environment.isRelease ? "Something went wrong." : error.legibleLocalizedDescription)
				theCode = (error as NSError).code
		}
		
		self.init(code: theCode, domain: (error as NSError).domain, message: reason)
	}
	
}
