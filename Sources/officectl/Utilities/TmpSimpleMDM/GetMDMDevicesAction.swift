/*
 * GetMDMDevicesAction.swift
 * officectl
 *
 * Created by François Lamboley on 2020/4/8.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import NIO
import OfficeKit
import SemiSingleton
import URLRequestOperation



final class GetMDMDevicesAction : Action<String, Void, [SimpleMDMDevice]>, SemiSingleton {
	
	/** The key is the token to be used to the calls to SimpleMDM */
	typealias SemiSingletonKey = String
	typealias SemiSingletonAdditionalInitInfo = Void
	
	required init(key: String, additionalInfo: Void, store: SemiSingletonStore) {
		super.init(subject: key)
	}
	
	override func unsafeStart(parameters: Void, handler: @escaping (Result<[SimpleMDMDevice], Error>) -> Void) throws {
		Task{handler(await Result{
			try await getAllDevices(token: subject)
		})}
	}
	
	private func getAllDevices(startingAfter previousMaxDeviceId: Int? = nil, token: String) async throws -> [SimpleMDMDevice] {
		func authenticate(_ request: URLRequest) -> URLRequest {
			var request = request
			request.addValue("Basic " + Data((token + ":").utf8).base64EncodedString(), forHTTPHeaderField: "Authorization")
			return request
		}
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		let op = try URLRequestDataOperation<Response>.forAPIRequest(
			url: URL(string: "https://a.simplemdm.com/api/v1/devices")!, urlParameters: Parameters(limit: 100/*max*/, startingAfter: previousMaxDeviceId),
			decoders: [decoder], requestProcessors: [AuthRequestProcessor(authHandler: authenticate)], retryProviders: []
		)
		/* Operation is async, we can launch it without a queue (though having a queue would be better…) */
		let response = try await op.startAndGetResult().result
		if !response.hasMore {
			return response.data
		}
		
		guard let latestDevice = response.data.last?.id else {
			throw InvalidArgumentError(message: "SimpleMDM returned no devices, but told it has more to give")
		}
		return try await response.data + getAllDevices(startingAfter: latestDevice, token: token)
		
		
		struct Parameters : Encodable {
			var limit: Int
			var startingAfter: Int?
			private enum CodingKeys : String, CodingKey {
				case limit, startingAfter = "starting_after"
			}
		}
		
		struct Response : Decodable {
			var data: [SimpleMDMDevice]
			var hasMore: Bool
		}
	}
	
}
