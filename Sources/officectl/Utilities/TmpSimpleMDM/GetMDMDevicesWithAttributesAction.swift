/*
 * GetMDMDevicesAction.swift
 * officectl
 *
 * Created by François Lamboley on 2020/4/8.
 */

import Foundation

import NIO
import OfficeKit
import SemiSingleton



final class GetMDMDevicesWithAttributesAction : Action<String, Void, [(SimpleMDMDevice, [String: String])]>, SemiSingleton {
	
	/** The key is the token to be used to the calls to SimpleMDM */
	typealias SemiSingletonKey = String
	typealias SemiSingletonAdditionalInitInfo = Void
	
	required init(key token: String, additionalInfo: Void, store: SemiSingletonStore) {
		getDevicesAction = store.semiSingleton(forKey: token)
		super.init(subject: token)
	}
	
	override func unsafeStart(parameters: Void, handler: @escaping (Result<[(SimpleMDMDevice, [String: String])], Error>) -> Void) throws {
		let eventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
		_ = getDevicesAction.start(parameters: (), weakeningMode: .always(successDelay: 3600, errorDelay: nil), shouldJoinRunningAction: { _ in true }, shouldRetrievePreviousRun: { _, wasSuccessful in wasSuccessful }, eventLoop: eventLoop)
		.flatMap{ devices -> EventLoopFuture<[(SimpleMDMDevice, [String: String])]> in
			let futures: [(SimpleMDMDevice, EventLoopFuture<[String: String]>)] = devices.map{ device in
				return (device, self.getDeviceAttributes(token: self.subject, deviceId: device.id, eventLoop: eventLoop))
			}
			/* waitAll returns an array of (SimpleMDM, Result<[String: String], Error>)
			 * The next flatMapThrowing will fail the whole future if any of the
			 * Result in the tuples is a failure, and drop the Result in its return
			 * type, effectively giving us an array of (SimpleMDM, [String: String])
			 * which is what we want! */
			return EventLoopFuture<[String: String]>.waitAll(futures, eventLoop: eventLoop)
			.flatMapThrowing{ result in
				try result.map{ try ($0.0, $0.1.get()) }
			}
		}
		.always{
			handler($0)
		}
	}
	
	private let getDevicesAction: GetMDMDevicesAction
	
	private func getDeviceAttributes(token: String, deviceId: Int, eventLoop: EventLoop) -> EventLoopFuture<[String: String]> {
		struct Response : Decodable {
			var data: [AttributesResponse]
			
			struct AttributesResponse : Decodable {
				/* Probably actually an enum; seems to always be
				 * “custom_attribute_value”. Not used. */
				var type: String
				var id: String
				var attributes: AttributesValueResponse
				struct AttributesValueResponse : Decodable {
					/* I cannot guarantee the value is non-optional and always a
					 * String (did not find confirmation in the doc) but this seems
					 * reasonable */
					var value: String
					/* I don’t know if SimpleMDM might send some other properties…
					 * For the cases I have today, I have nothing else. */
				}
			}
		}
		
		func authenticate(_ request: URLRequest, _ handler: @escaping (Result<URLRequest, Error>, Any?) -> Void) -> Void {
			var request = request
			request.addValue("Basic " + Data((token + ":").utf8).base64EncodedString(), forHTTPHeaderField: "Authorization")
			handler(.success(request), nil)
		}
		
		let url = URL(string: "https://a.simplemdm.com/api/v1/devices")!.appendingPathComponent(String(deviceId)).appendingPathComponent("custom_attribute_values")
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		let op = AuthenticatedJSONOperation<Response>(url: url, authenticator: authenticate, decoder: decoder)
		return EventLoopFuture<Response>.future(from: op, on: eventLoop).map{ response in
			/* We do not verify the API send only one value for a given key. */
			response.data.reduce(into: [String: String](), { $0[$1.id] = $1.attributes.value })
		}
	}
	
}
