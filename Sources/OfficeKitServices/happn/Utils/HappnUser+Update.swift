/*
 * HappnUser+Update.swift
 * HappnOffice
 *
 * Created by François Lamboley on 2022/11/18.
 */

import Foundation

import Email
import FormURLEncodedCoder
import URLRequestOperation

import OfficeKit



internal extension HappnUser {
	
	func update(properties: Set<HappnUser.CodingKeys>, connector: HappnConnector) async throws -> HappnUser {
		guard !properties.contains(.login), !properties.contains(.id) else {
			throw Err.unsupportedOperation
		}
		guard let userID = id else {
			throw Err.noPersistentID
		}
		
		let decoder = SendableJSONDecoder{
			$0.dateDecodingStrategy = .iso8601
		}
		
		let op = try URLRequestDataOperation<ApiResult<HappnUser>>.forAPIRequest(
			url: connector.baseURL.appending("api", "users", userID), method: "PUT"/* Partial apply should be PATCH in theory… */,
			urlParameters: ["fields": Self.validFieldsParameter(from: properties)],
			httpBody: self.forPatching(properties: properties),
			decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: [AuthRequestRetryProvider(connector)]
		)
		let result = try await op.startAndGetResult().result
		guard result.success, let updatedUser = result.data else {
			throw Err.apiError(code: result.errorCode, message: result.error ?? "Unknown error while updating user.")
		}
		return updatedUser
	}
	
}
