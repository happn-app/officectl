/*
 * IosTestDevicesController.swift
 * officectl
 *
 * Created by François Lamboley on 15/10/2019.
 */

import Foundation
#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

import SemiSingleton
import Vapor

import OfficeKit



final class IosTestDevicesController {
	
	func showTestDevicesList(_ req: Request) throws -> EventLoopFuture<View> {
		struct DevicesContext : Encodable {
			struct Device : Encodable {
				var name: String
				var dateLastSeen: String?
				var osVersion: String?
				var modelName: String?
				var udid: String?
				var phoneNumber: String?
				var serialNumber: String?
				var wifiMAC: String?
				var bluetoothMAC: String?
			}
			var devices: [Device]
		}
		
		let officectlConfig = req.make(OfficectlConfig.self)
		let token = try nil2throw(officectlConfig.tmpSimpleMDMToken)
		
		return getAllDevices(token: token, eventLoop: req.eventLoop).map{ devices in
			devices.filter{ $0.relationships.deviceGroup.id == 61452 }.sorted(by: { $0.attributes.deviceName < $1.attributes.deviceName }).map{
				DevicesContext.Device(
					name: $0.attributes.deviceName,
					dateLastSeen: $0.attributes.lastSeenAt,
					osVersion: $0.attributes.osVersion,
					modelName: $0.attributes.modelName,
					udid: $0.attributes.uniqueIdentifier,
					phoneNumber: $0.attributes.phoneNumber,
					serialNumber: $0.attributes.serialNumber,
					wifiMAC: $0.attributes.wifiMac,
					bluetoothMAC: $0.attributes.bluetoothMac
				)
			}
		}
		.flatMap{ devices in
			req.leaf.render("IosTestDevicesList", DevicesContext(devices: devices))
		}
	}
	
	private struct SimpleMDMDevice : Decodable {
		struct Attributes : Decodable {
			var name: String
			var lastSeenAt: String
			var status: String /* Technically an enum */
			var deviceName: String
			var osVersion: String?
			var buildVersion: String?
			var modelName: String?
			var model: String?
			var productName: String?
			var uniqueIdentifier: String?
			var serialNumber: String?
			var imei: String?
			var meid: String?
			var deviceCapacity: Float?
			var availableDeviceCapacity: Float?
			var batteryLevel: String?
			var modemFirmwareVersion: String?
			var iccid: String?
			var bluetoothMac: String?
			var ethernetMacs: [String]
			var wifiMac: String?
			var currentCarrierNetwork: String?
			var simCarrierNetwork: String?
			var subscriberCarrierNetwork: String?
			var carrierSettingsVersion: String?
			var phoneNumber: String?
			var voiceRoamingEnabled: Bool?
			var dataRoamingEnabled: Bool?
			var isRoaming: Bool?
			var subscriberMcc: String?
			var subscriberMnc: String?
			var simmnc: String? /* Not sure of actual type */
			var currentMcc: String?
			var currentMnc: String?
			var hardwareEncryptionCaps: Int?
			var passcodePresent: Bool?
			var passcodeCompliant: Bool?
			var passcodeCompliantWithProfiles: Bool?
			var isSupervised: Bool?
			var isDepEnrollment: Bool
			var isUserApprovedEnrollment: Bool?
			var isDeviceLocatorServiceEnabled: Bool?
			var isDoNotDisturbInEffect: Bool?
			var personalHotspotEnabled: Bool?
			var itunesStoreAccountIsActive: Bool?
			var cellularTechnology: Int?
			var lastCloudBackupDate: String?
			var isActivationLockEnabled: Bool
			var isCloudBackupEnabled: Bool
			var filevaultEnabled: Bool
			var filevaultRecoveryKey: String?
			var firmwarePasswordEnabled: Bool
			var firmwarePassword: String?
			var locationLatitude: String?
			var locationLongitude: String?
			var locationAccuracy: Int?
			var locationUpdatedAt: String?
		}
		
		struct DeviceGroup : Decodable {
			
			var id: Int
			var type: String /* Technically enum */
			
			init(from decoder: Decoder) throws {
				struct GroupData : Decodable {
					var type: String /* Technically enum */
					var id: Int
				}
				let container = try decoder.container(keyedBy: DeviceGroup.CodingKeys.self)
				let groupData = try container.decode(GroupData.self, forKey: .data)
				id = groupData.id
				type = groupData.type
			}
			
			private enum CodingKeys : String, CodingKey {
				case data
			}
			
		}
		
		struct Relationships : Decodable {
			var deviceGroup: DeviceGroup
		}
		
		var id: Int
		var attributes: Attributes
		var relationships: Relationships
		
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
				throw InvalidArgumentError(message: "No devices, but has more")
			}
			return self.getAllDevices(startingAfter: latestDevice, token: token, eventLoop: eventLoop).map{ response.data + $0 }
		}
		.flatMap{ $0 }
	}
	
}
