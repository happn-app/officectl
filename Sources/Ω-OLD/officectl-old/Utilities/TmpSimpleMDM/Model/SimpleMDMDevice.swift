/*
 * SimpleMDMDevice.swift
 * officectl
 *
 * Created by François Lamboley on 2020/4/8.
 */

import Foundation



struct SimpleMDMDevice : Decodable {
	
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
