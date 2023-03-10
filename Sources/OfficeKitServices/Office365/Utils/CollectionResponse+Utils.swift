/*
 * CollectionResponse+Utils.swift
 * Office365Office
 *
 * Created by François Lamboley on 2023/03/10.
 */

import Foundation

import URLRequestOperation

import OfficeKit



extension CollectionResponse {
	
	static func getAll(sourceRequest: URLRequest, requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = []) async throws -> [Element] {
		let decoder = SendableJSONDecoder{ _ in }
		let op = URLRequestDataOperation<CollectionResponse<Element>>.forAPIRequest(
			urlRequest: sourceRequest,
			decoders: [decoder],
			requestProcessors: requestProcessors, retryProviders: retryProviders
		)
		let collection = try await op.startAndGetResult().result
		if let nextURL = collection.nextLink {
			var request = sourceRequest
			request.url = nextURL
			let nextObjects = try await getAll(sourceRequest: request, requestProcessors: requestProcessors)
			return collection.value + nextObjects
		} else {
			return collection.value
		}
	}
	
}
