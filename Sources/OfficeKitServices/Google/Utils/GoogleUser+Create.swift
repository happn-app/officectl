/*
 * GoogleUser+Create.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/12/14.
 */

import Foundation

import Email
import UnwrapOrThrow
import URLRequestOperation

import OfficeKit2



internal extension GoogleUser {
	
	/* https://developers.google.com/admin-sdk/directory/v1/reference/users/get */
	func create(connector: GoogleConnector) async throws -> GoogleUser {
		let baseURL = URL(string: "https://www.googleapis.com/admin/directory/v1/")!
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = Conf.dateDecodingStrategy
		let createUserOperation = try URLRequestDataOperation<GoogleUser>.forAPIRequest(
			url: baseURL.appending("users"), httpBody: self,
			decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		)
		return try await createUserOperation.startAndGetResult().result
	}
	
}
