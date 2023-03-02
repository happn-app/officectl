/*
 * UpdateCAMetricsJob.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation

import Metrics
import Queues

import OfficeKit
import VaultPKIOffice



struct UpdateCAMetricsJob : AsyncScheduledJob {
	
	static let metricName = "happn_vault_certs_expiration"
	
	func run(context: Queues.QueueContext) async throws {
		/* First we delete the metric completely.
		 * This is mandatory to avoid old metrics of certificates turning invalid be left as a forever static metric. */
		Gauge(label: Self.metricName).destroy()
		
		let now = Date()
		let pkiServices = context.application.officeKitServices.userServices.compactMap{ $0 as? VaultPKIService }
		for pkiService in pkiServices {
			do {
				let certifs = try await pkiService.listAllCertificateMetadatas(includeRevoked: true)
				for certificate in certifs {
					guard let id = certificate.certifID else {
						context.logger.warning("Skipping certificate for expiration dates metrics as it does not have an ID.", metadata: [LMK.certifCN: "\(certificate.cn)"])
						continue
					}
					let dimensions = [
						("id", id),
						("common_name", certificate.cn),
//						("issuer_name", certificate.issuerName),
						("valid", certificate.isValid(at: now) ? "true" : "false"),
						("revoked", certificate.isRevoked(at: now) ? "true" : "false"),
						("key_usage_server_auth", certificate.keyUsageHasServerAuth ? "true" : "false"),
						("key_usage_client_auth", certificate.keyUsageHasClientAuth ? "true" : "false"),
//						certificate.certif.issuerDistinguishedName.flatMap{ ("issuer_dn", $0) },
//						certificate.certif.subjectDistinguishedName.flatMap{ ("subject_dn", $0) }
					].compactMap{ $0 }
					let gauge = Gauge(label: Self.metricName, dimensions: dimensions)
					gauge.record(certificate.expirationDate.timeIntervalSinceNow)
				}
			} catch {
				context.application.logger.error("Cannot update VaultPKI metrics.", metadata: [LMK.serviceID: "\(pkiService.id)"])
			}
		}
	}
	
}
