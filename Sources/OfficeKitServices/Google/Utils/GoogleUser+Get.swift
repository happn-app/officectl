/*
 * GoogleUser+Get.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/11/29.
 */

import Foundation

import Email
import UnwrapOrThrow
import URLRequestOperation

import OfficeKit



internal extension GoogleUser {
	
	/* <https://developers.google.com/admin-sdk/directory/v1/reference/users/get> */
	static func get(id: String, propertiesToFetch keys: Set<GoogleUser.CodingKeys>?, connector: GoogleConnector) async throws -> GoogleUser? {
		let baseURL = URL(string: "https://www.googleapis.com/admin/directory/v1/")!
		
		let urlParameters: [String: String]
		/* For now we do not use any custom fields in the user, so we always fetch the BASIC projection. */
		if let _ = keys {urlParameters = ["projection": "BASIC"]}
		else            {urlParameters = ["projection": "BASIC"]}
		
		let decoder = SendableJSONDecoder{
			$0.dateDecodingStrategy = Conf.dateDecodingStrategy
		}
		let op = try URLRequestDataOperation<GoogleUser>.forAPIRequest(
			url: try baseURL.appending("users", id), urlParameters: urlParameters,
			decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: [AuthRequestRetryProvider(connector)]
		)
		return try await op.startAndGetResult().result
	}
	
}
