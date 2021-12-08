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
		struct Response : Decodable {
			var data: [SimpleMDMDevice]
			var hasMore: Bool
		}
		
		func authenticate(_ request: URLRequest, _ handler: @escaping (Result<URLRequest, Error>, Any?) -> Void) -> Void {
			var request = request
			request.addValue("Basic " + Data((token + ":").utf8).base64EncodedString(), forHTTPHeaderField: "Authorization")
			handler(.success(request), nil)
		}
		
		var urlComponents = URLComponents(string: "https://a.simplemdm.com/api/v1/devices")!
		urlComponents.queryItems = [URLQueryItem(name: "limit", value: "100" /* max */)]
		if let previousMaxDeviceId = previousMaxDeviceId {
			urlComponents.queryItems!.append(URLQueryItem(name: "starting_after", value: "\(previousMaxDeviceId)"))
		}
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		let op = AuthenticatedJSONOperation<Response>(url: urlComponents.url!, authenticator: authenticate, decoder: decoder)
		/* Operation is async, we can launch it without a queue (though having a queue would be better…) */
		let response = try await op.startAndGetResult()
		if !response.hasMore {
			return response.data
		}
		
		guard let latestDevice = response.data.last?.id else {
			throw InvalidArgumentError(message: "SimpleMDM returned no devices, but told it has more to give")
		}
		return try await response.data + getAllDevices(startingAfter: latestDevice, token: token)
	}
	
}
