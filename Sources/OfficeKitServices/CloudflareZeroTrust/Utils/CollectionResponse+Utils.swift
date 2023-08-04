/*
 * CollectionResponse+Utils.swift
 * CloudflareZeroTrustOffice
 *
 * Created by François Lamboley on 2023/07/31.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import URLRequestOperation

import OfficeKit



extension CollectionResponse {
	
	static func getAll(sourceRequest: URLRequest, requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = []) async throws -> [Element] {
		let decoder = SendableJSONDecoder{ d in
			d.dateDecodingStrategy = .custom({ d in
#warning("TODO (obviously)")
				let container = try d.singleValueContainer()
//				try print(container.decode(String.self))
				return Date()
			})
		}
		let op = URLRequestDataOperation<CollectionResponse<Element>>.forAPIRequest(
			urlRequest: sourceRequest,
			decoders: [decoder],
			requestProcessors: requestProcessors, retryProviders: retryProviders
		)
		let collection = try await op.startAndGetResult().result
		if collection.resultInfo.count >= collection.resultInfo.perPage {
			guard let sourceURL = sourceRequest.url, var sourceComponents = URLComponents(url: sourceURL, resolvingAgainstBaseURL: true) else {
				throw Err.internalError("NO_URL_COMPONENTS")
			}
			sourceComponents.queryItems = (
				(sourceComponents.queryItems?.filter{ $0.name != "page" } ?? []) +
				[URLQueryItem(name: "page", value: String(collection.resultInfo.page + 1))]
			)
			guard let newURL = sourceComponents.url else {
				throw Err.internalError("NO_URL_FROM_COMPONENTS")
			}
			var newRequest = sourceRequest
			newRequest.url = newURL
			let nextObjects = try await getAll(sourceRequest: newRequest, requestProcessors: requestProcessors)
			return collection.result + nextObjects
		} else {
			return collection.result
		}
	}
	
}
