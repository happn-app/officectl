/*
 * HappnUser+Delete.swift
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
	
	func delete(connector: HappnConnector) async throws {
		guard let userID = id else {
			throw Err.noPersistentID
		}
		
		/* 1. Revoke user admin privileges. */
		
		/* We declare a decoded type HappnApiResult<Int8>.
		 * We chose Int8, but could have taken anything that’s decodable: the API returns null all the time… */
		let revokeOp = try URLRequestDataOperation<ApiResult<Int8>>.forAPIRequest(
			url: connector.baseURL.appending("api", "administrators"), httpBody: AdminActionRequestBody(action: "revoke", userID: userID, adminPassword: connector.password),
			bodyEncoder: FormURLEncodedEncoder(), requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		)
		_ = try await revokeOp.startAndGetResult()
		
		/* 2. Delete the user. */
		
		let deleteOp = try URLRequestDataOperation<ApiResult<Int8>>.forAPIRequest(
			url: connector.baseURL.appending("api", "users", userID), method: "DELETE", urlParameters: DeleteUserRequestQuery(),
			requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
		)
		await deleteOp.startAndWait() /* We don’t care about the error if any. */
	}
	
}
