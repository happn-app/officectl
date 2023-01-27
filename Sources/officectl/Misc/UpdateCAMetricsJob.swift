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
	
	func run(context: Queues.QueueContext) async throws {
		let pkiServices = context.application.officeKitServices.userServices.compactMap{ $0 as? VaultPKIService }
		for pkiService in pkiServices {
			do {
				/* TODO: We retrive here the list of the _users_, but we technically need the list of all the certificates (including from passive CAs).
				 *       For now the PKIUserService does not differentiate server certifs and client ones, so it does not matter.
				 *       Later we’ll do the distinction in the service and we’ll have to do differently here. */
				let users = try await pkiService.listAllUsers(includeSuspended: true, propertiesToFetch: nil)
				for certificate in users {
					guard let id = certificate.oU_persistentID,
//							let issuerName = certificate.oU_valueForProperty(UserProperty.vaultPKI_certificateIssuerName),
							let revoked = certificate.oU_isSuspended, /* TODO: This is not exactly true; isSuspended also checks expiration date. */
							let expirationDate = certificate.oU_valueForProperty(UserProperty.vaultPKI_certificateExpirationDate) as? Date
					else {
						context.logger.warning("Skipping certificate for expiration dates metrics as it is missing some properties.", metadata: [LMK.certifCN: "\(certificate.oU_id)"])
						continue
					}
					let dimensions = [
						("id", id),
						("common_name", certificate.oU_id),
//						("issuer_name", certificate.issuerName),
						("revoked", revoked ? "true" : "false"),
//						certificate.certif.issuerDistinguishedName.flatMap{ ("issuer_dn", $0) },
//						certificate.certif.subjectDistinguishedName.flatMap{ ("subject_dn", $0) }
					].compactMap{ $0 }
					let gauge = Gauge(label: "happn_vault_certs_expiration", dimensions: dimensions)
					gauge.record(expirationDate.timeIntervalSinceNow)
				}
			} catch {
				context.application.logger.error("Cannot update VaultPKI metrics.", metadata: [LMK.serviceID: "\(pkiService.id)"])
			}
		}
	}
	
}
