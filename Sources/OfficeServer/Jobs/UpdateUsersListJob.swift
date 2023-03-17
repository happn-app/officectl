/*
 * UpdateUsersListJob.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation

import Metrics
import Queues

import OfficeKit
import VaultPKIOffice



public struct UpdateUsersListJob : AsyncScheduledJob {
	
	public init() {
	}
	
	public func run(context: Queues.QueueContext) async throws {
		let multiUsersResult = try await MultiServicesUser.fetchAll(
			in: context.application.officeKitServices.hashableUserServices(matching: nil),
			includeSuspended: false
		)
		context.application.tempLocalCache_users = multiUsersAsTabularData(multiUsersResult.users)
	}
	
	/* Duplicated from officectl target. */
	private func multiUsersAsTabularData(_ multiUsers: [MultiServicesUser]) -> (keys: [String], values: [[String: String]]) {
		let allServices = Set(multiUsers.flatMap{ $0.keys }).sorted{ $0.value.id.rawValue < $1.value.id.rawValue }
		let values = multiUsers.map{ multiUser in
			return Dictionary(uniqueKeysWithValues: allServices.map{ service in
				let userStr: String
				switch multiUser[service] {
					case .none:               userStr = "<internal error>"
					case .success(nil)?:      userStr = "<none>"
					case .success(let user?): userStr = "\(UserAndServiceFrom(user: user, service: service.value)!.taggedID.id)"
					case .failure:            userStr = "ERROR"
				}
				return (service.value.id.rawValue, userStr)
			})
		}
		return (keys: allServices.map{ $0.value.id.rawValue }, values: values)
	}
	
}
