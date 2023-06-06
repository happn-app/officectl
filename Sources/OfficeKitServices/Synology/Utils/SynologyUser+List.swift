/*
 * SynologyUser+List.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import URLRequestOperation

import OfficeKit



extension SynologyUser {
	
	/* I did not find an actual doc for the users API for synology.
	 * Most of what we did is reverse engineer from DSM own webapp and from the DS Manager app. */
	static func getAll(includeSuspended: Bool = false, propertiesToFetch keys: Set<SynologyUser.CodingKeys>?, connector: SynologyConnector) async throws -> [SynologyUser] {
		let decoder = SendableJSONDecoder{ _ in }
		return try await URLRequestDataOperation<ApiResponse<UsersListResponseBody>>.forAPIRequest(
			urlRequest: try connector.urlRequestForEntryCGI(GETRequest: UsersListRequestBody(additionalFields: keys)),
			decoders: [decoder],
			requestProcessors: [AuthRequestProcessor(connector)],
			retryProviders: []
		).startAndGetResult().result.get().users
	}
	
}
