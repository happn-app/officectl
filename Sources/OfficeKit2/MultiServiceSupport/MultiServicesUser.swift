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
	
	static func fetch<Service : UserService>(from userAndService: UserAndServiceImpl<Service>, in services: Set<HashableUserService>, propertiesToFetch: Set<UserProperty> = [], using depServices: Services) async throws -> MultiServicesUser {
		var res = [HashableUserService: Result<(any User)?, ErrorCollection>]()
		var triedServiceIDSource = Set<HashableUserService>()
		
		func getUsers<UserAndServiceType : UserAndService>(from source: UserAndServiceType, in services: Set<HashableUserService>) async -> [HashableUserService: Result<(any User)?, Error>] {
			return await withTaskGroup(
				of: (service: HashableUserService, users: Result<(any User)?, Error>).self,
				returning: [HashableUserService: Result<(any User)?, Error>].self,
				body: { group in
					for service in services {
						group.addTask{
							let userResult = await Result{ try await service.value.existingUser(fromUserAndService: source, propertiesToFetch: propertiesToFetch, using: depServices) }
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
			/* Wrap the new results (fetchedUsersAndErrors) error in an ErrorCollection for easier merging with the current results (res). */
			let fetchedUsersAndErrors = fetchedUsersAndErrors.mapValues{ $0.mapError{ ErrorCollection([$0]) } }
			/* Merge the new results (fetchedUsersAndErrors) with our current results (res). */
			res.merge(fetchedUsersAndErrors, uniquingKeysWith: { currentResult, newResult in
				switch (currentResult, newResult) {
					case (.success, .success):
						OfficeKitConfig.logger?.error("Internal error: Got a user fetched twice. current result = \(currentResult), new result = \(newResult)")
						return newResult
						
					case (.success, .failure):
						OfficeKitConfig.logger?.error("Internal error: Got new failure for a result that was successfully fetched. current result = \(currentResult), new result = \(newResult)")
						return currentResult /* We keep the success… */
						
					case (.failure, .success):
						return newResult
						
					case let (.failure(currentFailure), .failure(newFailure)):
						return .failure(ErrorCollection(currentFailure.errors + newFailure.errors))
				}
			})
			
			/* Compute all the service for which we haven’t already successfully fetched a user (or its absence from the service),
			 *  and whose last fetch error was an inability to create a logical user from the source user.
			 * We estimate that if there was a fetch failure for a given service, there is no need to try again. */
			let servicesToFetch = services.filter{ service in
				guard let result = res[service] else {
					OfficeKitConfig.logger?.error("Internal error: Got a service which has no result, that should not be possible. service = \(service)")
					return true
				}
				return (result.failureValue?.errors.last as? Err)?.isCannotCreateLogicalUserFromWrappedUser ?? false
			}
			/* Compute all the service for which we have a user that we do not already have tried fetching from. */
			let servicesWithAUser = res.compactMap{
				let (key, value) = $0
				let hasUser: Bool
				switch value {
					case let .success(val): hasUser = (val != nil)
					case .failure:          hasUser = false
				}
				return hasUser ? key : nil
			}
			let servicesToTry = Set(servicesWithAUser).subtracting(triedServiceIDSource)
			
			guard let serviceToTry = servicesToTry.first, servicesToFetch.count > 0 else {
				/* We have finished. Let’s return the results. */
				return res.mapValues{ $0.mapError{ $0 as Error } }
			}
			let userAndServiceToTry = UserAndServiceFrom(user: res[serviceToTry]!.successValue!!, service: serviceToTry.value)!
			
			triedServiceIDSource.insert(serviceToTry)
			return await fetchStep(fetchedUsersAndErrors: getUsers(from: userAndServiceToTry, in: servicesToFetch))
		}
		
		return await fetchStep(fetchedUsersAndErrors: getUsers(from: userAndService, in: services))
	}
	
}
