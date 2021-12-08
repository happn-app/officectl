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



final class GetMDMDevicesWithAttributesAction : Action<String, Void, [(SimpleMDMDevice, [String: String])]>, SemiSingleton {
	
	/** The key is the token to be used to the calls to SimpleMDM */
	typealias SemiSingletonKey = String
	typealias SemiSingletonAdditionalInitInfo = Void
	
	required init(key token: String, additionalInfo: Void, store: SemiSingletonStore) {
		getDevicesAction = store.semiSingleton(forKey: token)
		super.init(subject: token)
	}
	
	override func unsafeStart(parameters: Void, handler: @escaping (Result<[(SimpleMDMDevice, [String: String])], Error>) -> Void) throws {
		Task{await handler(Result{
			let devices = try await getDevicesAction.start(parameters: (), weakeningMode: .always(successDelay: 3600, errorDelay: nil), shouldJoinRunningAction: { _ in true }, shouldRetrievePreviousRun: { _, wasSuccessful in wasSuccessful })
			return try await withThrowingTaskGroup(
				of: (SimpleMDMDevice, [String: String]).self,
				returning: [(SimpleMDMDevice, [String: String])].self,
				body: { group in
					for device in devices {
						group.addTask{
							return try await (device, self.getDeviceAttributes(token: self.subject, deviceId: device.id))
						}
					}
					
					var ret = [(SimpleMDMDevice, [String: String])]()
					while let curRet = try await group.next() {
						ret.append(curRet)
					}
					return ret
				}
			)
		})}
	}
	
	private let getDevicesAction: GetMDMDevicesAction
	
	private func getDeviceAttributes(token: String, deviceId: Int) async throws -> [String: String] {
		struct Response : Decodable {
			var data: [AttributesResponse]
			
			struct AttributesResponse : Decodable {
				/* Probably actually an enum; seems to always be “custom_attribute_value”.
				 * Not used. */
				var type: String
				var id: String
				var attributes: AttributesValueResponse
				struct AttributesValueResponse : Decodable {
					/* I cannot guarantee the value is non-optional and always a String (did not find confirmation in the doc) but this seems reasonable */
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
		/* Operation is async, we can launch it without a queue (though having a queue would be better…) */
		/* We do not verify the API send only one value for a given key. */
		return try await op.startAndGetResult().data.reduce(into: [String: String](), { $0[$1.id] = $1.attributes.value })
	}
	
}
