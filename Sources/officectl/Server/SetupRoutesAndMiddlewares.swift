/*
 * SetupRoutes.swift
 * officectl
 *
 * Created by François Lamboley on 2018/08/06.
 */

import Foundation

import OfficeKit
import OfficeModel
import Vapor



func setup_routes_and_middlewares(_ app: Application) throws {
	/* The officectl server now has two main routes groups: the API and the web routes.
	 * In theory it shouldn’t have the web routes, but here we are…
	 *
	 * Because of this, in order to have a clear separation of middlewares,
	 * in particular for the error middleware (api errors are JSON, web errors are HTML),
	 * but also for the file middleware (must only serve files if not in the /api “domain”),
	 * we must add the “catchAll” route to both the /api group and the web route!
	 *
	 * We have nevertheless left the standard error middleware (the API one) as a global middleware.
	 * That is, if the request matches NO routes, at least there will be a middleware to catch the error and the client won’t get a connection reset by peer.
	 * This should not happen though; all routes should be caught, either by the api or the web group, and we could in theory put the api error middleware in the api group.
	 *
	 * Note after the fact, discovery of unhandled routes:
	 * When POST-ing for instance on an unknown route, as the catch-all in on the GET only, we effectively get a fully unknown route!
	 * Whenever (if) we remove the web group one day, we should be able to fully get rid of all the groups
	 * (though we might as well keep the api one to avoid having to prefix all routes w/ api, or to prepare for a /api/v2 group ¯\_(ツ)_/¯).
	 * The “catchAll” should be removed though; it would not be of any use anymore. */
	
	/* Register global middlewares */
	/* Note: This middleware setup is the default. We simply make it explict. */
	app.middleware = Middlewares() /* Drop all default middlewares */
	app.middleware.use(ErrorMiddleware.default(environment: app.environment)) /* Catches errors and converts them to HTTP response (suitable for API) */
	
	let jwtAuth = UserJWTAuthenticator()
	let sessionAuth = UserSessionAuthenticator()
	let oauthClientAuth = OAuthClientAuthenticator()
	
	let loginGuard = LoggedInUser.guardMiddleware()
	let adminLoginGuard = LoggedInUser.guardAdminMiddleware()
	let loginGuardRedirect = LoggedInUser.redirectMiddlewareWithNextParam(baseURL: URL(string: "/login")!, nextParamName: "next")
	
	let fileMiddleware = FileMiddleware(publicDirectory: app.directory.publicDirectory) /* Serves files from the “Public” directory */
	let asyncErrorMiddleware = AsyncErrorMiddleware(processErrorHandler: handleWebError) /* Catches errors and converts them to HTTP response (suitable for web) */
	
	/* **************************** */
	/* ******** API Routes ******** */
	/* **************************** */
	
	let apiRoutesBuilder = app.grouped("api")
	let authedApiRoutesBuilder = apiRoutesBuilder.grouped(jwtAuth, loginGuard)
	let authedApiRoutesBuilderAdmin = authedApiRoutesBuilder.grouped(adminLoginGuard)
	apiRoutesBuilder.get("**", use: { _ -> String in throw Abort(.notFound) }) /* See first comment of this function for explanation of this. */
	
	apiRoutesBuilder.get("services", use: { req in
		req.application.officeKitConfig.serviceConfigs
			.map{ kv -> ApiService in
				let (_, config) = kv
				return ApiService(providerID: config.providerID, serviceID: config.serviceID, serviceFullName: config.serviceName, isHelperService: config.isHelperService)
			}
			.sorted(by: { $0.serviceFullName.localizedCompare($1.serviceFullName) != .orderedDescending })
	})
	
	let authController = AuthController()
	apiRoutesBuilder.grouped(oauthClientAuth).post("auth", "token",           use: authController.token)
	apiRoutesBuilder.grouped(oauthClientAuth).post("auth", "token", "revoke", use: authController.tokenRevoke)
	
	let usersController = UsersController()
	authedApiRoutesBuilderAdmin.get("users", use: usersController.getAllUsers)
	authedApiRoutesBuilder.get("users", "me", use: usersController.getMe)
	authedApiRoutesBuilder.get("users", ":dsuid-pair", use: usersController.getUser)
	
	/* Intentionnally not giving access to listing of all resets:
	 * We do not keep a table of the lists of password resets, and it would not be trivial to do, so we just don’t do it. */
	let passwordResetController = PasswordResetController()
	authedApiRoutesBuilder.get("password-resets", ":dsuid-pair", use: passwordResetController.getReset)
	authedApiRoutesBuilder.put("password-resets", ":dsuid-pair", use: passwordResetController.createReset)
	
	
	
	/* **************************** */
	/* ******** Web Routes ******** */
	/* **************************** */
	
	let webRoutesBuilder = app.grouped(asyncErrorMiddleware, fileMiddleware, app.sessions.middleware)
	let authedWebRoutesBuilder = webRoutesBuilder.grouped(sessionAuth)
	let authedWebRoutesBuilderGuard = authedWebRoutesBuilder.grouped(loginGuard)
	let authedWebRoutesBuilderRedir = authedWebRoutesBuilder.grouped(loginGuardRedirect)
	webRoutesBuilder.get("**", use: { _ -> View in throw Abort(.notFound) }) /* See first comment of this function for explanation of this. */
	
	/* ******** Login page & Auth check ******** */
	
	let webLoginController = WebLoginController()
	authedWebRoutesBuilder.get("login", use: webLoginController.showLoginPage)
	authedWebRoutesBuilder.post("login", use: webLoginController.doLogin)
	/* ↑ We use the session authenticator in order to save the login session on successful authentication, and not to use the user creds auth if unneeded. */
	
	authedWebRoutesBuilderGuard.get("auth-check", use: webLoginController.authCheck)
	
	/* Both endpoints below are used by nginx to check auth for Xcode Server.
	 * See comment on the `xcodeGuardMiddleware` function for explanations. */
	authedWebRoutesBuilder.grouped(LoggedInUser.xcodeGuardMiddleware(leeway: -1)).get("xcode-auth-check", use: webLoginController.authCheck)
	authedWebRoutesBuilder.grouped(LoggedInUser.xcodeGuardMiddleware(leeway:  7)).get("xcode-auth-check-lax", use: webLoginController.authCheck)
	
	/* ******** Home page ******** */
	
	authedWebRoutesBuilderRedir.get(use: WebHomeController().showHome)
	
	/* ******** Temporary password reset page ******** */
	
	let webPasswordResetController = WebPasswordResetController()
	authedWebRoutesBuilderRedir.get("password-reset", use: webPasswordResetController.showHome)
	authedWebRoutesBuilderRedir.get("password-reset",  ":email", use: webPasswordResetController.showResetPage)
	authedWebRoutesBuilderGuard.post("password-reset", ":email", use: webPasswordResetController.resetPassword)
	
	/* ******** Temporary certificate renew page ******** */
	
	let webCertificateRenewController = WebCertificateRenewController()
	authedWebRoutesBuilderRedir.get("get-certificate", use: webCertificateRenewController.showLogin)
	authedWebRoutesBuilderGuard.post("get-certificate", use: webCertificateRenewController.renewCertificate)
	
	/* ******** Temporary get licenses page ******** */
	
	let getLicensesController = GetLicensesController()
	authedWebRoutesBuilderRedir.get("get-licenses", use: getLicensesController.getLicenses)
	
	/* ******** Temporary test iOS devices list ******** */
	
	let iOSTestDevicesController = IosTestDevicesController()
	authedWebRoutesBuilderRedir.get("ios-test-devices", use: iOSTestDevicesController.showTestDevicesList)
	
	/* ******** Temporary list of all users ******** */
	
	let listUsersController = ListUsersController()
	authedWebRoutesBuilderRedir.get("list-users", use: listUsersController.showUsersList)
}


private func handleWebError(request: Request, chainingTo next: Responder, error: Error) async throws -> Response {
	request.logger.error("Error processing request: \(error.legibleLocalizedDescription)")
	
	let status = (error as? Abort)?.status
	let is404 = status?.code == 404
	let context = [
		"errorTitle": is404 ? "Page Not Found" : "Unknown Error",
		"errorDescription": is404 ? "This page was not found. Please go away!" : "\(error)"
	]
	
	return try await request.view.render("Error", context)
		.encodeResponse(status: status ?? .internalServerError, for: request)
}
