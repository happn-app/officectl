/*
 * GoogleUser+Update.swift
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
	
	/* <https://developers.google.com/admin-sdk/directory/reference/rest/v1/users/update> */
	func update(properties: Set<GoogleUser.CodingKeys>, connector: GoogleConnector) async throws -> GoogleUser {
		let baseURL = URL(string: "https://www.googleapis.com/admin/directory/v1/")!
		
		guard let userID = id else {
			throw Err.noPersistentID
		}
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = Conf.dateDecodingStrategy
		
		/* Partial apply should be PATCH, doc says PUT supports PATCH semantics.
		 * It also says PATCH is slower and clearing properties that are arrays is not possible with PATCH. */
		let op = try URLRequestDataOperation<GoogleUser>.forAPIRequest(
			url: baseURL.appending("users", userID), method: "PUT",
			httpBody: self.forPatching(properties: properties),
			decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		)
		return try await op.startAndGetResult().result
	}
	
}
