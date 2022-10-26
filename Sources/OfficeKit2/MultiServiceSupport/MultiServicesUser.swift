/*
 * MultiServicesUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2022/10/25.
 */

import Foundation

import ServiceKit



public typealias MultiServicesUser = [HashableUserService: Result<(any User)?, Error>]

public extension MultiServicesUser {
	
	static func fetch<Service : UserService>(from userAndService: UserAndService<Service>, in services: Set<HashableUserService>, propertiesToFetch: Set<UserProperty> = [], using depServices: Services) async throws -> MultiServicesUser {
		var allFetchedUsers = [HashableUserService: (any User)?]()
		var allFetchedErrors = [HashableUserService: [Error]]()
		var triedServiceIDSource = Set<HashableUserService>()
		
		func getUsers<ServiceType : UserService, UserType : User>(fromSourceUser sourceUser: UserType, sourceService: ServiceType, in services: Set<HashableUserService>) async -> [HashableUserService: Result<(any User)?, Error>] {
			/* We make sure this forced cast is valid when we call the function. */
			let sourceUser = sourceUser as! ServiceType.UserType
			return await withTaskGroup(
				of: (service: HashableUserService, users: Result<(any User)?, Error>).self,
				returning: [HashableUserService: Result<(any User)?, Error>].self,
				body: { group in
					for service in services {
						group.addTask{
							let userResult = await Result{ try await service.value.existingUser(fromUser: sourceUser, in: sourceService, propertiesToFetch: propertiesToFetch, using: depServices) }
							return (service, userResult)
						}
					}
					
					var users = [HashableUserService: Result<(any User)?, Error>]()
//					for await (service, userResult) in group { /* Crashes w/ Xcode 13.1 (13A1030d) */
					while let (service, userResult) = await group.next() {
						assert(users[service] == nil)
						users[service] = userResult
					}
					return users
				}
			)
		}
		
		func fetchStep(fetchedUsersAndErrors: [HashableUserService: Result<(any User)?, Error>]) async -> MultiServicesUser {
			/* Try and fetch the users that were not successfully fetched. */
			allFetchedUsers = allFetchedUsers.merging(fetchedUsersAndErrors.compactMapValues{ $0.successValue }, uniquingKeysWith: { old, new in
				OfficeKitConfig.logger?.error("Internal error: Got a user fetched twice for ID \(String(describing: old?.id ?? new?.id)). old user = \(String(describing: old)), new user = \(String(describing: new))")
				return new
			})
			allFetchedErrors = allFetchedErrors.merging(fetchedUsersAndErrors.compactMapValues{ $0.failureValue.flatMap{ [$0] } }, uniquingKeysWith: { old, new in old + new })
			
			/* Line below:
			 * All the service for which we haven’t already successfully fetched a user (or its absence from the service),
			 *  and whose last fetch error was an inability to create a logical user from the source user.
			 * We estimate that if there was a connection failure for a given service, there is no need to try again. */
			let servicesToFetch = services.filter{ !allFetchedUsers.keys.contains($0) && ((allFetchedErrors[$0]!.last as? Err)?.isCannotCreateLogicalUserFromWrappedUser ?? false) }
			/* Line below: All the service for which we have a user that we do not already have tried fetching from. */
			let servicesToTry = Set(allFetchedUsers.compactMap{ $0.value != nil ? $0.key : nil }).subtracting(triedServiceIDSource)
			
			guard let serviceToTry = servicesToTry.first, servicesToFetch.count > 0 else {
				/* We have finished. Let’s return the results. */
				return allFetchedUsers.mapValues{ Result<(any User)?, Error>.success($0) }
					.merging(allFetchedErrors.mapValues{ .failure(Err.errorCollection($0)) }, uniquingKeysWith: { _, _ in fatalError("Internal error.") })
			}
			
			triedServiceIDSource.insert(serviceToTry)
			return await fetchStep(fetchedUsersAndErrors: getUsers(fromSourceUser: allFetchedUsers[serviceToTry]!!, sourceService: serviceToTry.value, in: servicesToFetch))
		}
		
		return await fetchStep(fetchedUsersAndErrors: getUsers(fromSourceUser: userAndService.user, sourceService: userAndService.service, in: services))
	}
	
}
