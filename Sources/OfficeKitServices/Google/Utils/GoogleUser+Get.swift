/*
 * GoogleUser+Get.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/11/29.
 */

import Foundation

import Email
import GenericJSON
import UnwrapOrThrow
import URLRequestOperation

import OfficeKit2



internal extension GoogleUser {
	
	/* https://developers.google.com/admin-sdk/directory/v1/reference/users/get */
	static func get(id: String, propertiesToFetch keys: Set<GoogleUser.CodingKeys>, connector: GoogleConnector) async throws -> GoogleUser? {
		let baseURL = URL(string: "https://www.googleapis.com/admin/directory/v1/")!
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = Conf.dateDecodingStrategy
		let op = URLRequestDataOperation<GoogleUser>.forAPIRequest(
			url: try baseURL.appending("users", id),
			decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		)
		return try await op.startAndGetResult().result
	}
	
}
