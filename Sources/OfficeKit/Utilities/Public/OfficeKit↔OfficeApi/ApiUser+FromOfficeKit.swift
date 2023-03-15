/*
 * ApiMergedUserWithSource+FromOfficeKit.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/19.
 */

import Foundation

import Email
import Logging
import OrderedCollections

import OfficeModel



public extension ApiUser {
	
	init(multiServicesUser: MultiServicesUser, servicesMergePriority: [any UserService] = [], logger: Logger?) {
		let priority = Dictionary(uniqueKeysWithValues: servicesMergePriority.enumerated().map{ ($0.element.id, $0.offset) })
		let orderedUserAndServices = multiServicesUser
			.compactMap{ val -> (any UserAndService)? in
				let (hashableService, result) = val
				guard let user = try? result.get() else {
					return nil
				}
				return UserAndServiceFrom(user: user, service: hashableService.value)!
			}
			.sorted{ priority[$0.serviceID, default: .max] < priority[$1.serviceID, default: .max] }
		
		let emails = orderedUserAndServices.reduce(nil as OrderedSet<Email>?, { (currentEmails, userAndService) -> OrderedSet<Email>? in
			if let newEmails = userAndService.user.oU_emails {
				var currentEmails = currentEmails ?? []
				currentEmails.append(contentsOf: newEmails)
				return currentEmails
			} else {
				return currentEmails
			}
		})
		self.init(
			mergedResults: ApiMergedUser(
				ids: ApiMultiServicesID(taggedIDs: orderedUserAndServices.map{ $0.taggedID }),
				firstName: orderedUserAndServices.lazy.compactMap{ $0.user.oU_firstName }.first{ _ in true },
				lastName:  orderedUserAndServices.lazy.compactMap{ $0.user.oU_lastName  }.first{ _ in true },
				nickname:  orderedUserAndServices.lazy.compactMap{ $0.user.oU_nickname  }.first{ _ in true },
				emails: emails.flatMap(Array.init)
			),
			results: Dictionary(
				uniqueKeysWithValues: multiServicesUser
					.map{
						let (hashableServie, userResult) = $0
						return (hashableServie.value.id, userResult.mapError(ApiError.init(error:)).map{ optionalUser in
							guard let user = optionalUser else {
								return nil
							}
							let userAndService = UserAndServiceFrom(user: user, service: hashableServie.value)!
							return ApiDirectoryUser(userAndService: userAndService, logger: logger)
						})
					}
			)
		)
	}
	
}
