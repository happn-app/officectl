/*
 * LDAPConnector.swift
 * officectl
 *
 * Created by François Lamboley on 28/06/2018.
 */

import Foundation

import AsyncOperationResult

import COpenLDAP



@available(OSX, deprecated: 10.11) /* TODO: Rewrite a connector that uses OpenDirectory on macOS */
class LDAPConnector : Connector {
	
	enum LDAPProtocolVersion {
		
		case v1, v2, v3
		
		fileprivate var ldapVal: Int32 {
			switch self {
			case .v1: return LDAP_VERSION1
			case .v2: return LDAP_VERSION2
			case .v3: return LDAP_VERSION3
			}
		}
		
	}
	
	typealias ScopeType = Void
	
	let ldapURL: URL
	
	var currentScope: Void?
	let ldapPtr: OpaquePointer /* “LDAP*”; Cannot use the LDAP type (not exported to Swift, because opaque in C headers...) */
	
	let handlerOperationQueue = HandlerOperationQueue(name: "LDAPConnector")
	
	convenience init?(ldapURL u: URL, protocolVersion: LDAPProtocolVersion) {
		self.init(ldapURL: u, protocolVersion: protocolVersion, authMode: .none)
	}
	
	convenience init?(ldapURL u: URL, protocolVersion: LDAPProtocolVersion, username: String, password: String) {
		self.init(ldapURL: u, protocolVersion: protocolVersion, authMode: .userPass(username: username, password: password))
	}

	private init?(ldapURL u: URL, protocolVersion: LDAPProtocolVersion, authMode a: AuthMode) {
		ldapURL = u
		authMode = a
		
		/* As per the LDAP man, we single-thread the init...
		 *    “Note: the first call into the LDAP library also initializes the
		 *     global options for the library. As such the first call should be
		 *     single-threaded or otherwise protected to insure that only one call
		 *     is active. It is recommended that ldap_get_option() or
		 *     ldap_set_option() be used in the program's main thread before any
		 *     additional threads are created. See ldap_get_option(3).” */
		LDAPConnector.initSemaphore.wait()
		defer {LDAPConnector.initSemaphore.signal()}
		
		var ldapPtrInit: OpaquePointer? = nil
		let error = ldap_initialize(&ldapPtrInit, u.absoluteString)
		guard error == LDAP_SUCCESS, let ldapPtrInitNonNil = ldapPtrInit else {
			print("Cannot connect to LDAP with address \(u): \(error != LDAP_SUCCESS ? String(cString: ldap_err2string(error)) : "Internal error")", to: &stderrStream)
			return nil
		}
		ldapPtr = ldapPtrInitNonNil
		
		var v = protocolVersion.ldapVal
		let error2 = ldap_set_option(ldapPtr, LDAP_OPT_PROTOCOL_VERSION, &v)
		guard error2 == LDAP_OPT_SUCCESS else {
			print("Cannot set LDAP version to \(protocolVersion): \(String(cString: ldap_err2string(error2)))", to: &stderrStream)
			return nil
		}
	}
	
	deinit {
		ldap_unbind_ext_s(ldapPtr, nil, nil)
	}
	
	func unsafeConnect(scope: Void, handler: @escaping (Error?) -> Void) {
		switch authMode {
		case .none: handler(nil)
		case .userPass(username: let username, password: let password):
			guard let cStringPass = password.cString(using: .ascii) else {
				handler(NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Password cannot be converted to C String using ascii encoding"]))
				return
			}
			DispatchQueue(label: "LDAP Connector Connect Queue").async{
				var cred = berval(bv_len: ber_len_t(strlen(cStringPass)), bv_val: ber_strdup(cStringPass))
				defer {ber_memfree(cred.bv_val)}
				
				let r = ldap_sasl_bind_s(self.ldapPtr, username, nil, &cred, nil, nil, nil)
				guard r == LDAP_SUCCESS else {
					handler(NSError(domain: "com.happn.officectl.openldap", code: Int(r), userInfo: [NSLocalizedDescriptionKey: String(cString: ldap_err2string(r))]))
					return
				}
				
				handler(nil)
			}
		}
	}
	
	func unsafeDisconnect(handler: @escaping (Error?) -> Void) {
		handler(NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Disconnecting an LDAP connection but retaining the connection is not supported by (Open)LDAP"]))
	}
	
	/* ***************
      MARK: - Private
	   *************** */
	
	private static let initSemaphore = DispatchSemaphore(value: 1)
	
	private let authMode: AuthMode
	
	private enum AuthMode {
		
		case none
		case userPass(username: String, password: String)
		
	}
	
}
