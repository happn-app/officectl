/*
 * SyncOperationQueue.swift
 * officectl
 *
 * Created by François Lamboley on 14/06/2018.
 */

import Foundation



/** An operation queue which does not allow concurrent operation. */
public class SyncOperationQueue : OperationQueue {
	
	public override init() {
		super.init()
		
		super.maxConcurrentOperationCount = 1
	}
	
	/* This is needed because of Linux Swift. See OperationQueueUtils.swift */
	public convenience init(name n: String) {
		self.init()
		
		name = n
	}
	
	public override var maxConcurrentOperationCount: Int {
		get {
			return super.maxConcurrentOperationCount
		}
		set {
			fatalError("Attempted to change the maximum number of concurrent operation on a SyncOperationQueue. This is forbidden.")
		}
	}
	
}
