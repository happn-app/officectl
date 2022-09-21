/*
 * LDAPConnector.swift
 * officectl
 *
 * Created by François Lamboley on 2018/06/28.
 */

import Foundation

import APIConnectionProtocols
import TaskQueue

import COpenLDAP



/* Most of this class is adapted from https://github.com/PerfectlySoft/Perfect-LDAP/blob/master/Sources/PerfectLDAP/PerfectLDAP.swift */

public final actor LDAPConnector : Connector, HasTaskQueue {
	
	public static func isInvalidPassError(_ error: Error) -> Bool {
		let nsError = error as NSError
		return nsError.code == LDAP_INVALID_CREDENTIALS && nsError.domain == "com.happn.officectl.openldap"
	}
	
	/**
	 Sets the CA for all LDAP connections.
	 
	 I’d have like this to be able to be set on a connector basis instead of being global, but the option is global in the OpenLDAP lib. */
	public static func setCA(_ caURL: URL) throws {
		guard caURL.isFileURL else {
			throw NSError(domain: "com.happn.officectl.ldapconnector", code: 42, userInfo: [NSLocalizedDescriptionKey: "CA cert file must be a file URL"])
		}
		let error = ldap_set_option(nil, LDAP_OPT_X_TLS_CACERTFILE, caURL.path)
		guard error == LDAP_OPT_SUCCESS else {
			throw NSError(domain: "com.happn.officectl.openldap", code: Int(error), userInfo: [NSLocalizedDescriptionKey: "Cannot set TLS CA cert file to \(caURL) (some LDAP clients do not support this option)"])
		}
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
	
	public typealias Scope = Void
	public typealias Authentication = Void
	
	public let ldapURL: URL
	public let authMode: AuthMode
	
	public var currentScope: Void?
	
	public let connectorOperationQueue = SyncOperationQueue(name: "LDAPConnector")
	
	public init(ldapURL u: URL, protocolVersion: LDAPProtocolVersion, startTLS: Bool) throws {
		try self.init(ldapURL: u, protocolVersion: protocolVersion, startTLS: startTLS, authMode: .none)
	}
	
	public init(ldapURL u: URL, protocolVersion: LDAPProtocolVersion, startTLS: Bool, username: String, password: String) throws {
		try self.init(ldapURL: u, protocolVersion: protocolVersion, startTLS: startTLS, authMode: .userPass(username: username, password: password))
	}
	
	init(ldapURL u: URL, protocolVersion: LDAPProtocolVersion, startTLS: Bool, authMode a: AuthMode) throws {
		ldapURL = u
		authMode = a
		
		/* As per the LDAP man, we single-thread the init...
		 *
		 * “Note: the first call into the LDAP library also initializes the global options for the library.
		 *  As such the first call should be single-threaded or otherwise protected to insure that only one call is active.
		 *  It is recommended that ldap_get_option() or ldap_set_option() be used in the program's main thread before any additional threads are created.
		 *  See ldap_get_option(3).” */
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
	
	/**
	 Lets the client communicate directly with the LDAP.
	 Use the pointer inside the block only, do **not** store it!
	 
	 - Parameter communicationBlock: The block to execute.
	 - Parameter ldapPtr: An opaque pointer to the underlying LDAP C structure.
	 The structure is opaque in the openldap headers, so we get an opaque pointer in Swift. */
	public func performLDAPCommunication<T>(_ communicationBlock: (_ ldapPtr: OpaquePointer) throws -> T) rethrows -> T {
		/* If I understand the actor principle correctly, it is not possible this function is called twice in parallel,
		 * so there should not be any need for a synchronization queue. */
		return try communicationBlock(ldapPtr)
	}
	
	/* ********************************
	   MARK: - Connector Implementation
	   ******************************** */
	
	public func unqueuedConnect(scope: Void, auth: Void) async throws -> Void {
		switch authMode {
			case .none:
				self.currentScope = scope
				return
				
			case .userPass(username: let username, password: let password):
				guard let cStringPass = password.cString(using: .ascii) else {
					throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Password cannot be converted to C String using ascii encoding"])
				}
				currentScope = try await withCheckedThrowingContinuation{ continuation in
					DispatchQueue(label: "LDAP Connector Connect Queue").async{continuation.resume(with: Result{
						var cred = berval(bv_len: ber_len_t(strlen(cStringPass)), bv_val: ber_strdup(cStringPass))
						defer {ber_memfree(cred.bv_val)}
						
						/* TODO: https://twitter.com/CodaFi_/status/1362671988171370496 */
						let r = ldap_sasl_bind_s(self.ldapPtr, username, nil, &cred, nil, nil, nil)
						guard r == LDAP_SUCCESS else {
							throw NSError(domain: "com.happn.officectl.openldap", code: Int(r), userInfo: [NSLocalizedDescriptionKey: String(cString: ldap_err2string(r))])
						}
						
						return scope
					})}
				}
		}
	}
	
	public func unqueuedDisconnect() async throws {
		throw NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Disconnecting an LDAP connection but retaining the connection is not supported by (Open)LDAP"])
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/** Technically public because it fulfill the HasTaskQueue requirement, but should not be used directly. */
	public var _taskQueue = TaskQueue()
	
	private static let initSemaphore = DispatchSemaphore(value: 1)
	
	private let ldapPtr: OpaquePointer /* “LDAP*”; Cannot use the LDAP type (not exported to Swift, because opaque in C headers...) */
	
}
