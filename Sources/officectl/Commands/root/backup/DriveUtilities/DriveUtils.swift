/*
 * DriveUtils.swift
 * officectl
 *
 * Created by François Lamboley on 11/02/2020.
 */

import Foundation

import GenericJSON
import OfficeKit
import URLRequestOperation



enum DriveUtils {
	
	static func retryRecoveryHandler(_ operation: URLRequestOperationWithRetryRecoveryHandler, sourceError error: Error, completionHandler: @escaping (URLRequestOperation.RetryMode, URLRequest, Error?) -> Void) {
		let jsonDecoder = JSONDecoder()
		guard
			let data = operation.fetchedData,
			let json = try? jsonDecoder.decode(JSON.self, from: data),
			let _ = json["error"]?["errors"]?.arrayValue?.first(where: { $0["domain"]?.stringValue == "usageLimits" && $0["reason"]?.stringValue == "userRateLimitExceeded" })
		else {
			return completionHandler(.doNotRetry, operation.currentURLRequest, error)
		}
		completionHandler(.retry(withDelay: 100, enableReachability: false, enableOtherRequestsObserver: false), operation.currentURLRequest, nil)
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
