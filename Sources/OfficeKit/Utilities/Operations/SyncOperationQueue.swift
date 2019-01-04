/*
 * SyncOperationQueue.swift
 * officectl
 *
 * Created by François Lamboley on 14/06/2018.
 */

import Foundation



/** An operation queue which does not allow concurrent operation. */
public class SyncOperationQueue : OperationQueue {
	
	public override var maxConcurrentOperationCount: Int {
		get {
			return 1
		}
		set {
			fatalError("Attempted to change the maximum number of concurrent operation on a SyncOperationQueue. This is forbidden.")
		}
	}
	
}
