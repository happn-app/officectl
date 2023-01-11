/*
 * routes.swift
 * officectl-odproxy
 *
 * Created by François Lamboley on 2019/07/10.
 */

import Foundation

import Vapor

import OfficeKit2
import OpenDirectoryOffice



func configureRoutes(_ app: Application, _ serverConfig: ServerConfig, _ odService: OpenDirectoryService) throws {
	/* ********* Register Middlewares ********* */
	
	app.middleware.use(VerifySignatureMiddleware(
		secret: Data(serverConfig.secret.utf8),
		signatureURLPathPrefixTransform: serverConfig.signatureURLPathPrefixTransform)
	)
	
	
	/* ********* Register Routes ********* */
	
	let serviceController = ServiceController(odService: odService)
	app.post("existing-user-from-id",            use: serviceController.existingUserFromID)
	app.post("existing-user-from-persistent-id", use: serviceController.existingUserFromPersistentID)
	app.post("list-all-users",                   use: serviceController.listAllUsers)
}
