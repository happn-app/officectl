/*
 * serve.swift
 * officectl
 *
 * Created by François Lamboley on 2018/07/26.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import ArgumentParser
import Metrics
@preconcurrency import Vapor

import OfficeKit



struct ServerServeCommand : AsyncParsableCommand {
	
	struct Options : ParsableArguments {
		
		/* Note: We do **not** provide the bind option because I don’t like it
		 * (because of IPv6; Vapor simply ignores there are hostname that can contain semicolons;
		 *  I don’t want to ignore that but also want to be as compatible as possible with Vapor’s options,
		 *  so the best solution is to simply not provide the bind option).
		 * Also, not providing the bind option simplifies the hostname and port selection! */
		
		@ArgumentParser.Option(name: [.customShort("H"), .long], help: "The hostname the server will run on. Defaults to localhost.")
		var hostname: String?
		
		@ArgumentParser.Option(name: .shortAndLong, help: "The port the server will run on. Defaults to 8080.")
		var port: Int?
		
		@ArgumentParser.Option(name: .long, help: "The secret to use for generating the JWT tokens.")
		var jwtSecret: String?
		
	}
	
	static var configuration = CommandConfiguration(
		commandName: "serve",
		abstract: "Start the server."
	)
	
	@OptionGroup()
	var globalOptions: OfficectlRootCommand.Options
	
	@OptionGroup()
	var serverOptions: Options
	
	func run() async throws {
		let config = try OfficectlConfig(globalOptions: globalOptions, serverOptions: serverOptions)
		try Application.runSync(officectlConfig: config, configureHandler: setup_routes_and_middlewares, vaporRun)
	}
	
	func vaporRun(_ context: CommandContext) async throws {
		let app = context.application
		let config = app.officectlConfig
		
		guard let serverConfig = config.serverConfig else {
			throw "Internal error: serverConfig is nil for the serve command!"
		}
		
		guard let serveCommand = app.commands.commands["serve"] else {
			throw "Cannot find the serve command"
		}
		
		/* Before launching the server, we launch a background task to update the certificates expiration dates metric. */
		if let vaultBaseURL = config.tmpVaultBaseURL?.appendingPathComponent("v1"),
			let issuerName = config.tmpVaultIssuerName,
			let token = config.tmpVaultToken
		{
			let additionalActiveIssuers = config.tmpVaultAdditionalActiveIssuers ?? []
			let additionalPassiveIssuers = config.tmpVaultAdditionalPassiveIssuers ?? []
			
			@Sendable
			func authenticate(_ request: URLRequest) -> URLRequest {
				var request = request
				request.addValue(token, forHTTPHeaderField: "X-Vault-Token")
				return request
			}
			let queue = DispatchQueue(label: "com.happn.cronjob")
			var updateCertifExpiryDate: (() -> Void)?
			updateCertifExpiryDate = {
				app.logger.info("Launching certificate expiry computation.")
				let updateCertifExpiryDate = updateCertifExpiryDate!
				Task{
					do {
						let certificates = try await ([issuerName] + additionalActiveIssuers + additionalPassiveIssuers).concurrentFlatMap{ issuerName -> [Certificate] in
							return try await Certificate.getAll(
								from: issuerName,
								includeRevoked: true,
								vaultBaseURL: vaultBaseURL,
								vaultAuthenticator: AuthRequestProcessor(authHandler: authenticate)
							)
						}
						for certificate in certificates {
							let dimensions = [
								("id", normalizeCertificateID(certificate.id)),
								("common-name", certificate.commonName),
								("issuer-name", certificate.issuerName),
								("revoked", certificate.isRevoked ? "true" : "false"),
								certificate.certif.issuerDistinguishedName.flatMap{ ("issuer-dn", $0) },
								certificate.certif.subjectDistinguishedName.flatMap{ ("subject-dn", $0) }
							].compactMap{ $0 }
							let gauge = Gauge(label: "happn_vault_certs_expiration", dimensions: dimensions)
							if let notAfter = certificate.certif.notAfter {
								gauge.record(notAfter.timeIntervalSinceNow)
							}
						}
					} catch {
						app.logger.error("Failed updating certificate expiration date metrics.", metadata: ["error": "\(error)"])
					}
					queue.asyncAfter(deadline: .now() + .seconds(12 * 60 * 60), execute: updateCertifExpiryDate)
				}
			}
			updateCertifExpiryDate!()
		}
		
		var context = context
		context.input = CommandInput(arguments: ["fake vapor", "--port", String(serverConfig.serverPort), "--hostname", serverConfig.serverHost])
		
		try serveCommand.run(using: &context)
	}
	
}
