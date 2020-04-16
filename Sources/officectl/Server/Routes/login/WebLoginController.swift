/*
 * WebLoginController.swift
 * officectl
 *
 * Created by François Lamboley on 16/04/2020.
 */

import Foundation

import NIO
import OfficeKit
import Vapor



class WebLoginController {
	
	func showLoginPage(_ req: Request) throws -> EventLoopFuture<View> {
		req.logger.info(.init(stringLiteral: String(describing: req.session.data["token"])))
		req.session.data["token"] = "hello!"
		throw NotImplementedError()
	}
	
	func doLogin(_ req: Request) throws -> EventLoopFuture<View> {
		throw NotImplementedError()
	}
	
}
