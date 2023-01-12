/*
 * ConfsForTests.swift
 * OfficeKitTests
 *
 * Created by François Lamboley on 2019/08/17.
 */

import Foundation

import OfficeKit



let globalConf = GlobalConfig()

let ldapBaseDNForTests = try! LDAPDistinguishedName(string: "dc=happn,dc=test")
let ldapConfForTests = LDAPServiceConfig(
	providerID: LDAPService.providerID,
	serviceID: "ldap", serviceName: "LDAP", mergePriority: nil,
	connectorSettings: LDAPConnector.Settings(
		ldapURL: URL(string: "ldap://localhost:8389")!,
		protocolVersion: .v3,
		startTLS: false,
		username: "cn=admin," + ldapBaseDNForTests.stringValue,
		password: "toto"
	),
	baseDNs: LDAPBaseDNs(baseDNPerDomain: ["happn.test": ldapBaseDNForTests], peopleDN: nil), adminGroupsDN: []
)
