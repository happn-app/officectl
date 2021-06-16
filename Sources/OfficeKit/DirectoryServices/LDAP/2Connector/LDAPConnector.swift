/*
 * LDAPConnector.swift
 * officectl
 *
 * Created by François Lamboley on 28/06/2018.
 */

import Foundation

import COpenLDAP



/* Most of this class is adapted from https://github.com/PerfectlySoft/Perfect-LDAP/blob/master/Sources/PerfectLDAP/PerfectLDAP.swift */

public final class LDAPConnector : Connector {
	
	public static func isInvalidPassError(_ error: Error) -> Bool {
		let nsError = error as NSError
		return nsError.code == LDAP_INVALID_CREDENTIALS && nsError.domain == "com.happn.officectl.openldap"
	}
	
	public enum LDAPProtocolVersion : Hashable {
		
		case v1, v2, v3
		
		fileprivate var ldapVal: Int32 {
			switch self {
			case .v1: return LDAP_VERSION1
			case .v2: return LDAP_VERSION2
			case .v3: return LDAP_VERSION3
			}
		}
		
	}
	
	public enum AuthMode : Hashable {
		
		case none
		case userPass(username: String, password: String)
		
	}
	
	public typealias ScopeType = Void
	
	public let ldapURL: URL
	public let authMode: AuthMode
	
	public var currentScope: Void?
	
	public let connectorOperationQueue = SyncOperationQueue(name: "LDAPConnector")
	
	public convenience init(ldapURL u: URL, protocolVersion: LDAPProtocolVersion, startTLS: Bool, caCertFile: URL?) throws {
		try self.init(ldapURL: u, protocolVersion: protocolVersion, startTLS: startTLS, caCertFile: caCertFile, authMode: .none)
	}
	
	public convenience init(ldapURL u: URL, protocolVersion: LDAPProtocolVersion, startTLS: Bool, caCertFile: URL?, username: String, password: String) throws {
		try self.init(ldapURL: u, protocolVersion: protocolVersion, startTLS: startTLS, caCertFile: caCertFile, authMode: .userPass(username: username, password: password))
	}
	
	init(ldapURL u: URL, protocolVersion: LDAPProtocolVersion, startTLS: Bool, caCertFile: URL?, authMode a: AuthMode) throws {
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
			throw NSError(domain: "com.happn.officectl.openldap", code: Int(error), userInfo: [NSLocalizedDescriptionKey: "Cannot connect to LDAP with address \(u): \(error != LDAP_SUCCESS ? String(cString: ldap_err2string(error)) : "Internal error")"])
		}
		ldapPtr = ldapPtrInitNonNil
		
		var v = protocolVersion.ldapVal
		let error2 = ldap_set_option(ldapPtr, LDAP_OPT_PROTOCOL_VERSION, &v)
		guard error2 == LDAP_OPT_SUCCESS else {
			throw NSError(domain: "com.happn.officectl.openldap", code: Int(error2), userInfo: [NSLocalizedDescriptionKey: "Cannot set LDAP version to \(protocolVersion)"])
		}
		
		if let caCertFile = caCertFile {
			guard caCertFile.isFileURL else {
				throw NSError(domain: "com.happn.officectl.openldap", code: Int(error), userInfo: [NSLocalizedDescriptionKey: "CA cert file must be a file URL"])
			}
			let error = ldap_set_option(ldapPtr, LDAP_OPT_X_TLS_CACERTFILE, caCertFile.path)
			guard error == LDAP_OPT_SUCCESS else {
				throw NSError(domain: "com.happn.officectl.openldap", code: Int(error), userInfo: [NSLocalizedDescriptionKey: "Cannot set TLS CA cert file to \(caCertFile) (some LDAP clients do not support this option)"])
			}
		}
		
		if startTLS {
			let error = ldap_start_tls_s(self.ldapPtr, nil, nil)
			guard error == LDAP_SUCCESS else {
				throw NSError(domain: "com.happn.officectl.openldap", code: Int(error), userInfo: [NSLocalizedDescriptionKey: "Cannot StartTLS on connection: \(String(cString: ldap_err2string(error)))"])
			}
		}
	}
	
	deinit {
		ldap_unbind_ext_s(ldapPtr, nil, nil)
	}
	
	/** Lets the client communicate directly with the LDAP. Use the pointer
	inside the block only, do **not** store it!
	
	- Parameter communicationBlock: The block to execute.
	- Parameter ldapPtr: An opaque pointer to the underlying LDAP C structure.
	The structure is opaque in the openldap headers, so we get an opaque pointer
	in Swift. */
	public func performLDAPCommunication<T>(_ communicationBlock: (_ ldapPtr: OpaquePointer) throws -> T) rethrows -> T {
		return try ldapCommunicationQueue.sync{ try communicationBlock(ldapPtr) }
	}
	
	/* ********************************
	   MARK: - Connector Implementation
	   ******************************** */
	
	public func unsafeChangeCurrentScope(changeType: ChangeScopeOperationType<Void>, handler: @escaping (Error?) -> Void) {
		switch changeType {
		case .remove, .removeAll:
			handler(NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Disconnecting an LDAP connection but retaining the connection is not supported by (Open)LDAP"]))
			
		case .add(let scope):
			switch authMode {
			case .none:
				self.currentScope = scope
				handler(nil)
				
			case .userPass(username: let username, password: let password):
				guard let cStringPass = password.cString(using: .ascii) else {
					handler(NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Password cannot be converted to C String using ascii encoding"]))
					return
				}
				DispatchQueue(label: "LDAP Connector Connect Queue").async{
					var cred = berval(bv_len: ber_len_t(strlen(cStringPass)), bv_val: ber_strdup(cStringPass))
					defer {ber_memfree(cred.bv_val)}
					
					/* TODO: https://twitter.com/CodaFi_/status/1362671988171370496 */
					let r = ldap_sasl_bind_s(self.ldapPtr, username, nil, &cred, nil, nil, nil)
					guard r == LDAP_SUCCESS else {
						handler(NSError(domain: "com.happn.officectl.openldap", code: Int(r), userInfo: [NSLocalizedDescriptionKey: String(cString: ldap_err2string(r))]))
						return
					}
					
					self.currentScope = scope
					handler(nil)
				}
			}
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private static let initSemaphore = DispatchSemaphore(value: 1)
	
	private let ldapCommunicationQueue = DispatchQueue(label: "LDAPConnector Communication Queue")
	private let ldapPtr: OpaquePointer /* “LDAP*”; Cannot use the LDAP type (not exported to Swift, because opaque in C headers...) */
	
}
