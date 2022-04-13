/*
 * IosTestDevicesController.swift
 * officectl
 *
 * Created by François Lamboley on 2019/10/15.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import SemiSingleton
import UnwrapOrThrow
import Vapor

import OfficeKit



final class IosTestDevicesController {
	
	func showTestDevicesList(_ req: Request) async throws -> View {
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
		
		let officectlConfig = req.application.officectlConfig
		let semiSingletonStore = req.application.semiSingletonStore
		let token = try officectlConfig.tmpSimpleMDMToken ?! MissingFieldError("tmpSimpleMDMToken")
		
		let getDevicesAction: GetMDMDevicesAction = semiSingletonStore.semiSingleton(forKey: token)
		let devices = try await getDevicesAction.start(parameters: (), weakeningMode: .always(successDelay: 3600, errorDelay: nil), shouldJoinRunningAction: { _ in true }, shouldRetrievePreviousRun: { _, wasSuccessful in wasSuccessful })
			.filter{ $0.relationships.deviceGroup.id == 61452 }
			.sorted(by: { $0.attributes.deviceName < $1.attributes.deviceName })
			.map{
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
		
		return try await req.view.render("IosTestDevicesList", DevicesContext(devices: devices))
	}
	
}
