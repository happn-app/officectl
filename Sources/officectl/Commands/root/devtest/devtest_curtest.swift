/*
 * devtest_curtest.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Guaka
import Foundation



class CurTestOperation : CommandOperation {
	
	override func startBaseOperation(isRetry: Bool) {
		let c = LDAPConnector()
		c.connect(scope: ()){ error in
			self.baseOperationEnded()
		}
	}
	
}
