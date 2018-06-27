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
//		let c = HappnConnector(
//			clientId: "AtCialX437NjAPynnGWJzJt_FbnIFncNpUY-Vl8SMs", clientSecret: "ts4f2BQPkfCv1ooqt2G8WveOTggFKkin9tDvkmbX17",
//			username: "francois.lamboley@happn.fr", password: "REDACTED"
//		)
		let c = HappnConnector(
			clientId: "AtCialX437NjAPynnGWJzJt_FbnIFncNpUY-Vl8SMs", clientSecret: "ts4f2BQPkfCv1ooqt2G8WveOTggFKkin9tDvkmbX17",
			refreshToken: "kj9b234gv279mnppknrr4ida700oaq1l06"
		)
		c.connect(scope: ["admin_scopes", "mobile_app"]){ error in
			print(c.currentScope)
			print(c.accessToken)
			self.baseOperationEnded()
		}
	}
	
}
