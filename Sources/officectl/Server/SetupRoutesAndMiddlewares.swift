/*
 * SetupRoutes.swift
 * officectl
 *
 * Created by François Lamboley on 06/08/2018.
 */

import Foundation

import OfficeKit
import Vapor



func setup_routes_and_middlewares(_ app: Application) throws {
	/* The officectl server now has two main routes groups: the API and the web
	 * routes. In theory it shouldn’t have the web routes, but here we are…
	 *
	 * Because of this, in order to have a clear separation of middlewares, in
	 * particular for the error middleware (api errors are JSON, web errors are
	 * HTML), but also for the file middleware (must only serve files if not in
	 * the /api “domain”), we must add the “catchAll” route to both the /api
	 * group and the web route!
	 * We have nevertheless left the standard error middleware (the API one) as
	 * a global middleware. That is, if the request matches NO routes, at least
	 * there will be a middleware to catch the error and the client won’t get a
	 * connection reset by peer. This should not happen though; all routes should
	 * be caught, either by the api or the web group, and we could in theory put
	 * the api error middleware in the api group.
	 * Whenever (if) we remove the web group one day, we should be able to fully
	 * get rid of all the groups (though we might as well keep the api one to
	 * avoid having to prefix all routes w/ api, or to prepare for a /api/v2
	 * group ¯\_(ツ)_/¯). The “catchAll” should be removed though; it would not
	 * be of any use anymore. */
	
	/* Register global middlewares */
	/* Note: This middleware setup is the default. We simply make it explict. */
	app.middleware = Middlewares() /* Drop all default middlewares */
	app.middleware.use(ErrorMiddleware.default(environment: app.environment)) /* Catches errors and converts them to HTTP response (suitable for API) */
	
	let bearerAuth = UserBearerAuthenticator()
	let sessionAuth = UserSessionAuthenticator()
	let loginGuard = LoggedInUser.guardMiddleware()
	let adminLoginGuard = LoggedInUser.guardAdminMiddleware()
	
	let fileMiddleware = FileMiddleware(publicDirectory: app.directory.publicDirectory) /* Serves files from the “Public” directory */
	let asyncErrorMiddleware = AsyncErrorMiddleware(processErrorHandler: handleWebError) /* Catches errors and converts them to HTTP response (suitable for web) */
	
	/* **************************** */
	/* ******** API Routes ******** */
	/* **************************** */
	
	let apiRoutesBuilder = app.grouped("api")
	let authedApiRoutesBuilder = apiRoutesBuilder.grouped(bearerAuth, loginGuard)
	let authedAdminApiRoutesBuilder = authedApiRoutesBuilder.grouped(adminLoginGuard)
	apiRoutesBuilder.get("**", use: { _ -> String in throw Abort(.notFound) }) /* See first comment of this function for explanation of this. */
	
	apiRoutesBuilder.get("services", use: { req in
		ApiResponse.data(
			req.application.officeKitConfig.serviceConfigs
			.map{ kv -> ApiService in
				let (_, config) = kv
				return ApiService(providerId: config.providerId, serviceId: config.serviceId, serviceFullName: config.serviceName, isHelperService: config.isHelperService)
			}
			.sorted(by: { $0.serviceFullName.localizedCompare($1.serviceFullName) != .orderedDescending })
		)
	})
	
	apiRoutesBuilder.grouped(UserCredsAuthenticator(usernameType: .taggedId))
		.post("auth", "login",  use: LoginController().login)
	apiRoutesBuilder.post("auth", "logout", use: LogoutController().logout)
	
	let usersController = UsersController()
	authedAdminApiRoutesBuilder.get("users", use: usersController.getAllUsers)
	authedApiRoutesBuilder.get("users", "me", use: usersController.getMe)
	authedApiRoutesBuilder.get("users", ":dsuid-pair", use: usersController.getUser)
	
	/* Intentionnally not giving access to listing of all resets: We do not keep
	 * a table of the lists of password resets, and it would not be trivial to do
	 * so we just don’t do it. */
	let passwordResetController = PasswordResetController()
	authedApiRoutesBuilder.get("password-resets", ":dsuid-pair", use: passwordResetController.getReset)
	authedApiRoutesBuilder.put("password-resets", ":dsuid-pair", use: passwordResetController.createReset)
	
	
	
	/* **************************** */
	/* ******** Web Routes ******** */
	/* **************************** */
	
	let webRoutesBuilder = app.grouped(asyncErrorMiddleware, fileMiddleware, app.sessions.middleware)
	let authedWebRoutesBuilderNoGuard = webRoutesBuilder.grouped(sessionAuth)
	let authedWebRoutesBuilder = authedWebRoutesBuilderNoGuard.grouped(loginGuard)
	webRoutesBuilder.get("**", use: { _ -> View in throw Abort(.notFound) }) /* See first comment of this function for explanation of this. */
	webRoutesBuilder.get(use: { _ -> View in throw Abort(.notFound) }) /* Get "/". Should be caught by ** but it is not: https://github.com/vapor/vapor/issues/2288 */
	
	/* ******** Login page ******** */
	
	let webLoginController = WebLoginController()
	authedWebRoutesBuilderNoGuard.get("login", use: webLoginController.showLoginPage)
	authedWebRoutesBuilderNoGuard.grouped(UserCredsAuthenticator(usernameType: .email))
		.post("login", use: webLoginController.doLogin)
	/* ↑ We use the session authenticator in order to save the login session on
	 * successful authentication, and not to use the user creds auth if unneeded. */
	
	/* ******** Temporary password reset page ******** */
	
	let webPasswordResetController = WebPasswordResetController()
	webRoutesBuilder.get("password-reset", use: webPasswordResetController.showUserSelection)
	webRoutesBuilder.get("password-reset",  ":email", use: webPasswordResetController.showResetPage)
	webRoutesBuilder.post("password-reset", ":email", use: webPasswordResetController.resetPassword)
	
	/* ******** Temporary certificate renew page ******** */
	
	let webCertificateRenewController = WebCertificateRenewController()
	webRoutesBuilder.get("get-certificate", use: webCertificateRenewController.showLogin)
	webRoutesBuilder.post("get-certificate", use: webCertificateRenewController.renewCertificate)
	
	/* ******** Temporary get licenses page ******** */
	
	let getLicensesController = GetLicensesController()
	webRoutesBuilder.get("get-licenses", use: getLicensesController.showLogin)
	webRoutesBuilder.post("get-licenses", use: getLicensesController.getLicenses)
	
	/* ******** Temporary test iOS devices list ******** */
	
	let iOSTestDevicesController = IosTestDevicesController()
	webRoutesBuilder.get("ios-test-devices", use: iOSTestDevicesController.showTestDevicesList)
}


private func handleWebError(request: Request, chainingTo next: Responder, error: Error) throws -> EventLoopFuture<Response> {
	request.logger.error("Error processing request: \(error.legibleLocalizedDescription)")
	
	let status = (error as? Abort)?.status
	let is404 = status?.code == 404
	let context = [
		"errorTitle": is404 ? "Page Not Found" : "Unknown Error",
		"errorDescription": is404 ? "This page was not found. Please go away!" : "\(error)"
	]
	
	return request.view.render("ErrorPage", context).flatMap{ view in
		return view.encodeResponse(status: status ?? .internalServerError, for: request)
	}
}
