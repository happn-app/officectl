/*
 * Utils.swift
 * GitHubOffice
 *
 * Created by François Lamboley on 2022/12/30.
 */

import Foundation

import CollectionConcurrencyKit
import OperationAwaiting
import URLRequestOperation

import OfficeKit



enum Utils {
	
	static func getAll<Object : Decodable & Sendable>(baseURL: URL, pathComponents: [String], connector: GitHubConnector) async throws -> [Object] {
		let nPerPage = 100 /* max possible */
		
		var pageNumber = 1
		var curResult: [Object]
		var allResults = [Object]()
		repeat {
			let op = try URLRequestDataOperation<[Object]>.forAPIRequest(
				url: baseURL.appendingPathComponentsSafely(pathComponents).appendingQueryParameters(from: ["per_page": nPerPage, "page": pageNumber]),
				requestProcessors: [AuthRequestProcessor(connector)], retryProviders: []
			)
			curResult = try await op.startAndGetResult().result.map{ $0 }
			allResults.append(contentsOf: curResult)
			pageNumber += 1
		} while curResult.count >= nPerPage
		return allResults
	}
	
}
