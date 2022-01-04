/*
 * routes.swift
 * officectl_odproxy
 *
 * Created by François Lamboley on 2019/07/10.
 */

import Foundation

import OfficeKit
import Vapor
import GenericStorage



func routes_and_middlewares(_ app: Application, _ serverConfig: GenericStorage) throws {
	let serverSecret = try serverConfig.string(forKey: "secret", currentKeyPath: ["Server Config"])
	
	let signatureURLPathPrefixTransform: VerifySignatureMiddleware.SignatureURLPathPrefixTransform?
	if let transformObject = try serverConfig.optionalNonNullStorage(forKey: "signature_url_path_prefix_transform", currentKeyPath: ["Server Config"]) {
		signatureURLPathPrefixTransform = (
			from: try transformObject.string(forKey: "from", currentKeyPath: ["Signature URL Prefix Transform"]),
			to:   try transformObject.string(forKey: "to",   currentKeyPath: ["Signature URL Prefix Transform"])
		)
	} else {
		signatureURLPathPrefixTransform = nil
	}
	
	/* Register middlewares */
	app.middleware.use(ErrorMiddleware(handleError)) /* Catches errors and converts them to HTTP response */
	app.middleware.use(VerifySignatureMiddleware(secret: Data(serverSecret.utf8), signatureURLPathPrefixTransform: signatureURLPathPrefixTransform))
	
	/* ********* Register routes ********* */
	
	let userSearchController = UserSearchController()
	app.post("existing-user-from", "persistent-id", use: userSearchController.fromPersistentID)
	app.post("existing-user-from", "user-id",       use: userSearchController.fromUserID)
	app.get("list-all-users",                       use: userSearchController.listAllUsers)
	
	let userController = UserController()
	app.post("create-user",     use: userController.createUser)
	app.post("update-user",     use: userController.updateUser)
	app.post("delete-user",     use: userController.deleteUser)
	app.post("change-password", use: userController.changePassword)
}


private func handleError(req: Request, error: Error) -> Response {
	do {
		req.logger.error("Error processing request: \(error)")
		return try ApiResponse<String>(error: error).syncEncode(for: req)
	} catch {
		var headers = HTTPHeaders()
		headers.replaceOrAdd(name: .contentType, value: "application/json")
		return Response(status: .internalServerError, headers: headers, body: Response.Body(string: #"{"error":{"domain":"top","code":42,"message":"Cannot even encode the upstream error…"}}"#))
	}
}
