/*
 * GetLicensesController.swift
 * officectl
 *
 * Created by François Lamboley on 2020/4/7.
 */

import Foundation
#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

import OfficeKit
import URLRequestOperation
import Vapor



class GetLicensesController {
	
	func showLogin(_ req: Request) throws -> EventLoopFuture<View> {
		return req.view.render("GetLicensesLogin")
	}
	
	func getLicenses(_ req: Request) throws -> EventLoopFuture<View> {
		throw NotImplementedError()
	}
	
}
