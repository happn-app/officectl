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
		let eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
		_ = getAllDevices(token: subject, eventLoop: eventLoop).always{
			handler($0)
		}
	}
	
	private func getAllDevices(startingAfter previousMaxDeviceId: Int? = nil, token: String, eventLoop: EventLoop) -> EventLoopFuture<[SimpleMDMDevice]> {
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
		return EventLoopFuture<Response>.future(from: op, on: eventLoop)
		.flatMapThrowing{ response in
			if !response.hasMore {
				return eventLoop.future(response.data)
			}
			
			guard let latestDevice = response.data.last?.id else {
				throw InvalidArgumentError(message: "SimpleMDM returned no devices, but told it has more to give")
			}
			return self.getAllDevices(startingAfter: latestDevice, token: token, eventLoop: eventLoop).map{ response.data + $0 }
		}
		.flatMap{ $0 }
	}
	
}
