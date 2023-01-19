/*
 * ApiMergedUserWithSource+FromOfficeKit.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/19.
 */

import Foundation

import Logging

import OfficeKit
import OfficeModel



extension ApiMergedUserWithSource {
	
	init(multiServicesUser: MultiServicesUser, servicesPriority: [any UserService] = []) {
		let priority = Dictionary(uniqueKeysWithValues: servicesPriority.enumerated().map{ ($0.element.id, $0.offset) })
		let orderedUserAndServices = multiServicesUser
			.compactMap{ val -> (any UserAndService)? in
				let (hashableService, result) = val
				guard let user = try? result.get() else {
					return nil
				}
				return UserAndServiceFrom(user: user, service: hashableService.value)!
			}
			.sorted{ priority[$0.serviceID, default: .max] < priority[$1.serviceID, default: .max] }
		self.init(
			firstName: orderedUserAndServices.lazy.compactMap{ $0.user.oU_firstName }.first{ _ in true },
			lastName:  orderedUserAndServices.lazy.compactMap{ $0.user.oU_lastName  }.first{ _ in true },
			nickname:  orderedUserAndServices.lazy.compactMap{ $0.user.oU_nickname  }.first{ _ in true },
			emails: <#T##[Email]?#>, directoryUsers: <#T##[String : Result<ApiDirectoryUser?, ApiError>]#>)
	}
	
}
