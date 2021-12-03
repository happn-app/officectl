/*
 * GetLicensesController.swift
 * officectl
 *
 * Created by François Lamboley on 2020/4/7.
 */

import Foundation
#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif

import OfficeKit
import URLRequestOperation
import Vapor



class GetLicensesController {
	
	func getLicenses(_ req: Request) async throws -> View {
		let loggedInUser = try req.auth.require(LoggedInUser.self)
		
		let emailService: EmailService = try req.application.officeKitServiceProvider.getService(id: nil)
		let emailStr = try loggedInUser.user.hop(to: emailService).user.userId.stringValue
		
		let officectlConfig = req.application.officectlConfig
		let semiSingletonStore = req.application.semiSingletonStore
		let token = try nil2throw(officectlConfig.tmpSimpleMDMToken)
		
		let getDevicesAction: GetMDMDevicesWithAttributesAction = semiSingletonStore.semiSingleton(forKey: token)
		return try await getDevicesAction.start(parameters: (), weakeningMode: .always(successDelay: 3600, errorDelay: nil), shouldJoinRunningAction: { _ in true }, shouldRetrievePreviousRun: { _, wasSuccessful in wasSuccessful }, eventLoop: req.eventLoop)
		.flatMapThrowing{ devicesAndAttributes -> [[String: String]] in
			return devicesAndAttributes.compactMap{ deviceAndAttributes -> [[String: String]]? in
				guard deviceAndAttributes.1["user_email"] == emailStr else {return nil}
				
				guard
					let licensesStr = deviceAndAttributes.1["software_licenses"]?
						.splitLines()
						.map({ $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) })
						.filter({ !$0.isEmpty })
				else {return nil}
				
				let jsonDecoder = JSONDecoder()
				return licensesStr.compactMap{ licenseStr -> [String: String]? in
					guard let license = try? jsonDecoder.decode(Dictionary<String, String>.self, from: Data(licenseStr.utf8)) else {
						req.logger.warning("Found invalid license (cannot decode as [String: String]) stored for user \(emailStr) in device \(deviceAndAttributes.0.id)")
						return nil
					}
					return license
				}
			}
			.flatMap{ $0 }
		}
		.flatMap{ licenses -> EventLoopFuture<View> in
			struct LicencesContext : Encodable {
				var email: String
				var columnNames: [String]
				var licenses: [[String: String]]
			}
			
			let context = LicencesContext(email: emailStr, columnNames: Array(licenses.reduce(Set<String>(), { $0.union($1.keys) })).sorted(), licenses: licenses)
			return req.view.render("GetLicenses", context)
		}
		.get()
	}
	
}


private extension String {
	
	func splitLines() -> [String] {
		var res = [String]()
		enumerateLines{ line, _ in res.append(line) }
		return res
	}
	
}
