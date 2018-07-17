/*
 * LDAPPerson.swift
 * OfficeKit
 *
 * Created by François Lamboley on 16/07/2018.
 */

import Foundation



/* http://www.faqs.org/rfcs/rfc4519.html */
public class LDAPPerson : LDAPTop {
	
	public var sn: [String] /* 2.5.4.4 — The surname (family name) of the person */
	public var cn: [String] /* 2.5.4.3 — The common name of the person (typically its full name) */
	
	public var userPassword: String?
	
	public init(dn dname: String, sn surname: [String], cn commonName: [String]) {
		sn = surname
		cn = commonName
		
		super.init(dn: dname)
	}
	
}
