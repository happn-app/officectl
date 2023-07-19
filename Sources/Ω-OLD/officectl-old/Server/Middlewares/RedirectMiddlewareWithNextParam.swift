/*
 * RedirectMiddlewareWithNextParam.swift
 * officectl
 *
 * Created by François Lamboley on 2020/04/20.
 */

import Foundation

import Vapor



extension Authenticatable {
	
	/**
	 The same as the redirect middleware from Vapor, but w/ support for a “next param” to pass to the redirected path (e.g. `?next=original_url`).
	 
	 This middleware does not support passing the full original request, only the original URL.
	 
	 `baseURL` should probably be an absolute URL without a host or scheme, but can also be relative, or even contain a hostname.
	 It can also contain a query string and a fragment.
	 The “next” parameter, if any, will be added to the alreay present query of the base path.
	 
	 - Note: The redirect middleware from vapor has evolved rendering this basically useless, but I’m currently migrating to async, not anything else. */
	public static func redirectMiddlewareWithNextParam(baseURL: URL, nextParamName: String?) -> Middleware {
		return RedirectMiddlewareWithNextParam<Self>(Self.self, baseURL: baseURL, nextParamName: nextParamName)
	}
}


private struct RedirectMiddlewareWithNextParam<A : Authenticatable> : AsyncMiddleware {
	
	let baseURLComponents: URLComponents
	let nextParamName: String?
	
	init(_ authenticatableType: A.Type = A.self, baseURL url: URL, nextParamName npn: String?) {
		/* About that force unwrap…
		 * I have no idea when URLComponents fails to retrieve the components from a URL, so we’ll say it always work.
		 * In any case this init should always be called when the server starts, thus failing soon (and crashing) if failing… */
		baseURLComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
		nextParamName = npn
	}
	
	func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
		if req.auth.has(A.self) {
			return try await next.respond(to: req)
		}
		var newComponents = baseURLComponents
		if let p = nextParamName, let u = req.url.string.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) {
			newComponents.queryItems = (newComponents.queryItems ?? []) + [URLQueryItem(name: p, value: u)]
		}
		guard let redirectURL = newComponents.url else {
			throw Abort(.internalServerError, reason: "Cannot convert URLComponent to URL…")
		}
		
		return req.redirect(to: redirectURL.absoluteString)
	}
	
}
