/*
 * OperationQueueUtils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/01/02.
 */

import Foundation



extension OperationQueue {
	
	/* This should be named init(name:), but when building on Linux, intantiating SyncOperationQueue with the name argument does not work…
	 * so for now we use an alternate name to init with name on OperationQueue, and we have another init(name:) for SyncOperationQueue :( */
	public convenience init(name_OperationQueue n: String) {
		self.init()
		
		name = n
	}
	
}
