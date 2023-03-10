/*
 * HappnUser+Create.swift
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
	
	func create(connector: HappnConnector) async throws -> HappnUser {
		let decoder = SendableJSONDecoder{
			$0.dateDecodingStrategy = .iso8601
			$0.keyDecodingStrategy = .useDefaultKeys
		}
		
		guard password != nil else {
			/* A user must be created w/ a password (or we get a weird error when creating the account, and the account is unusable though it appear to exist). */
			throw Err.unsupportedOperation
		}
		
		/* 1. Create the user. */
		
		let createUserOperation = try URLRequestDataOperation<ApiResult<HappnUser>>.forAPIRequest(
			url: connector.baseURL.appending("api", "users"),
			urlParameters: ["fields": Self.validFieldsParameter(from: Self.keysFromProperties(nil))], httpBody: self,
			decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: [AuthRequestRetryProvider(connector)]
		)
		let apiUserResult = try await createUserOperation.startAndGetResult().result
		guard apiUserResult.success, let user = apiUserResult.data, let userID = user.id else {
			throw Err.apiError(code: apiUserResult.errorCode, message: apiUserResult.error ?? "Unknown error while creating the user.")
		}
		
		/* 2. Make it an admin. */
		
		/* We declare a decoded type HappnApiResult<Int8>.
		 * We chose Int8, but could have taken anything that’s decodable: the API returns null all the time… */
		let makeUserAdminOperation = try URLRequestDataOperation<ApiResult<Int8>>.forAPIRequest(
			url: connector.baseURL.appending("api", "administrators"), httpBody: AdminActionRequestBody(action: "grant", userID: userID, adminPassword: connector.password),
			bodyEncoder: FormURLEncodedEncoder(), decoders: [decoder], requestProcessors: [AuthRequestProcessor(connector)], retryProviders: [AuthRequestRetryProvider(connector)]
		)
		let apiGrantResult = try await makeUserAdminOperation.startAndGetResult().result
		guard apiGrantResult.success else {
			throw Err.apiError(code: apiGrantResult.errorCode, message: apiGrantResult.error ?? "Unknown error while granting user admin access.")
		}
		
		/* 3. Set the ACLs. */
		// POST /api/user-acls
		// Data: x-www-form-urlencoded
		//    - permissions: ...
		//    - user_id: ...
		// Response: null (in a standard response)
		
		return user
	}
	
}
