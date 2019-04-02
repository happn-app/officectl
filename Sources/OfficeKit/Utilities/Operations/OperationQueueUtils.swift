/*
 * OperationQueueUtils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 02/01/2019.
 */

import Foundation



extension OperationQueue {
	
	public convenience init(name n: String) {
		self.init()
		
		name = n
	}
	
}
