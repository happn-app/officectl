/*
 * RateLimiterOperation.swift
 * officectl
 *
 * Created by François Lamboley on 11/02/2020.
 */

import Foundation

import RetryingOperation



class RateLimiterOperation : RetryingOperation {
	
	struct Limit {
		
		enum TimeLimit {
			
			case duration(TimeInterval)
			case resetAtDateComponents(DateComponents, calendar: Calendar)
			
		}
		
		var maxCount: Int
		var time: TimeLimit
		
	}
	
	let rateLimitId: String
	let limits: [Limit]
	
	init(id: String, limits l: [Limit]) {
		rateLimitId = id
		limits = l
	}
	
	override func startBaseOperation(isRetry: Bool) {
		/* Try and acquire the lock */
		let timeToWait: TimeInterval? = RateLimiterOperation.countsQueue.sync{
			let timesToWait = limits.compactMap{ limit -> TimeInterval? in
				let previousResetDateO: Date?
				switch limit.time {
					case .duration(let i):                                         previousResetDateO = Date() - i
					case .resetAtDateComponents(let dateComponents, let calendar): previousResetDateO = calendar.nextDate(after: Date(), matching: dateComponents, matchingPolicy: .strict, repeatedTimePolicy: .first, direction: .backward)
				}
				
				guard let previousResetDate = previousResetDateO else {return nil}
				
				let nHits: Int
				let counts = RateLimiterOperation.counts[rateLimitId, default: []]
				/* TODO: Optimize this search (reverse search). Currently, the more dates are registered, the longer the search! */
				let dateAndOffset = counts.enumerated().first{ $0.element >= previousResetDate } /* The last date that was rate-limited */
				if let dateAndOffset = dateAndOffset {
					nHits = counts.count - dateAndOffset.offset
				} else {
					/* If no dates are after the reset date, that means none of the registered dates are in the rate-limit period.*/
					nHits = 0
				}
				
				guard nHits >= limit.maxCount else {return nil}
				
				let nextResetDate: Date?
				switch limit.time {
					case .duration(let i):                                                   nextResetDate = (dateAndOffset?.element ?? counts.last).flatMap{ $0 + i }
					case .resetAtDateComponents(let dateComponents, calendar: let calendar): nextResetDate = calendar.nextDate(after: Date(), matching: dateComponents, matchingPolicy: .strict, repeatedTimePolicy: .first, direction: .forward)
				}
				return nextResetDate?.timeIntervalSinceNow
			}
			
			if let t = timesToWait.max() {
				if t >= 0 {return t}
			}
			/* If we don’t wait, we register the call in the counts variable. */
			RateLimiterOperation.counts[rateLimitId, default: []].append(Date())
			return nil
		}
		
		if let t = timeToWait {baseOperationEnded(needsRetryIn: t)}
		else                  {baseOperationEnded()}
	}
	
	/* The base operation is not in itself asynchronous, but there’s no need to wait the next available slot synchronously, so let’s say we’re async. */
	override var isAsynchronous: Bool {
		return true
	}
	
	private static let countsQueue = DispatchQueue(label: "com.happn.officectl.ratelimiter_counts_queue")
	private static var counts = [String: [Date]]()
	
}
