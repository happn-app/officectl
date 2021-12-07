/*
 * ConfsForTests.swift
 * OfficeKitTests
 *
 * Created by François Lamboley on 17/08/2019.
 */

import Foundation

import OfficeKit



let globalConf = GlobalConfig()

let ldapBaseDNForTests = try! LDAPDistinguishedName(string: "dc=happn,dc=test")
let ldapConfForTests = LDAPServiceConfig(
	providerId: LDAPService.providerId,
	serviceId: "ldap", serviceName: "LDAP", mergePriority: nil,
	connectorSettings: LDAPConnector.Settings(
		ldapURL: URL(string: "ldap://localhost:8389")!,
		protocolVersion: .v3,
		startTLS: false,
		username: "cn=admin," + ldapBaseDNForTests.stringValue,
		password: "toto"
	),
	baseDNs: LDAPBaseDNs(baseDNPerDomain: ["happn.test": ldapBaseDNForTests], peopleDN: nil), adminGroupsDN: []
)
