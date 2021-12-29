/*
 * DriveUtils.swift
 * officectl
 *
 * Created by François Lamboley on 2020/02/11.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import GenericJSON
import OfficeKit
import RetryingOperation
import URLRequestOperation



class RateLimitRetryProvider : RetryProvider {
	
	var maxRetries: Int?
	var retryCount: Int = 0
	
	init(maxRetries: Int? = nil) {
		self.maxRetries = maxRetries
	}
	
	func retryHelpers(for request: URLRequest, error: Error, operation: URLRequestOperation) -> [RetryHelper]?? {
		guard
			let data = (error as? URLRequestOperationError)?.unexpectedStatusCodeError?.httpBody,
			DriveUtils.isRateLimitError(data: data)
		else {
			/* Not usage limit exceeded error, we do not provide a retry helper. */
			return nil
		}
		guard retryCount < (maxRetries ?? .max) else {return nil}
		retryCount += 1
		return [RetryingOperation.TimerRetryHelper(retryDelay: NetworkErrorRetryProvider.exponentialBackoffTimeForIndex(3), retryingOperation: operation)]
	}
	
}


enum DriveUtils {
	
	static func isRateLimitError(data: Data) -> Bool {
		/* We expect this:
		 * {
		 * 	"error": {
		 * 		"errors": [
		 * 			{
		 * 				"domain": "usageLimits",
		 * 				"reason": "dailyLimitExceeded",
		 * 				"message": "Daily Limit Exceeded"
		 * 			}
		 * 		],
		 * 		"code": 403,
		 * 		"message": "Daily Limit Exceeded"
		 * 	}
		 * }
		 * Note that because I’m not sure gougle’s apis always return a structured error that has the same format,
		 * I did not create URLRequestOperations with a structured error, and thus I have to parse it manually here. */
		struct ExpectedAPIError : Decodable {
			struct GErr : Decodable {
				struct GErr2 : Decodable {
					var domain: String
					var reason: String
					var message: String
				}
				var errors: [GErr2]
				var code: Int
				var message: String
			}
			var error: GErr
		}
		if
			let apiError = try? JSONDecoder().decode(ExpectedAPIError.self, from: data),
			apiError.error.errors.contains(where: { $0.domain == "usageLimits" && $0.reason == "userRateLimitExceeded" })
		{
			return true
		} else {
			return false
		}
	}
	
	static func rateLimitGoogleDriveAPIOperation<T : Operation>(_ operation: T, queue: OperationQueue = OfficeKit.defaultOperationQueueForFutureSupport) -> T {
		let dateComponents = DateComponents(hour: nil, minute: nil, second: 0, nanosecond: 0)
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(abbreviation: "PST")!
		
		let rateLimitOperation = RateLimiterOperation(id: "google_drive_limits", limits: [
			RateLimiterOperation.Limit(maxCount: 10,            time: .duration(1)), /* Not officially in the list of quota, but the word of the street is this exists… */
			RateLimiterOperation.Limit(maxCount: 1_000,         time: .duration(100)),
			RateLimiterOperation.Limit(maxCount: 1_000_000_000, time: .resetAtDateComponents(dateComponents, calendar: calendar))
		])
		
		operation.addDependency(rateLimitOperation)
		queue.addOperation(rateLimitOperation)
		return operation
	}
	
}
