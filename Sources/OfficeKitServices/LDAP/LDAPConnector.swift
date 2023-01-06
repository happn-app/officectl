/*
 * LDAPConnector.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation

import APIConnectionProtocols
import TaskQueue

import COpenLDAP



public final actor LDAPConnector : Connector, HasTaskQueue {
	
	/**
	 Sets the CA for all LDAP connections.
	 
	 I’d have like this to be able to be set on a connector basis instead of being global, but the option is global in the OpenLDAP lib. */
	public static func setCA(_ caFilePath: String) throws {
		let error = ldap_set_option(nil, LDAP_OPT_X_TLS_CACERTFILE, caFilePath)
		guard error == LDAP_OPT_SUCCESS else {
			throw OpenLDAPError(code: error)
		}
	}
	
	public enum ProtocolVersion : String, Sendable, Hashable, Codable {
		
		case v1, v2, v3
		
		fileprivate var ldapVal: Int32 {
			switch self {
				case .v1: return LDAP_VERSION1
				case .v2: return LDAP_VERSION2
				case .v3: return LDAP_VERSION3
			}
		}
		
	}
	
	public enum Auth : Sendable, Hashable, Codable {
		
		case userPass(username: String, password: String)
		
	}
	
	public typealias Authentication = Void
	
	public let ldapURL: URL
	public let version: ProtocolVersion
	public let startTLS: Bool
	
	public let auth: Auth?
	
	/* We do not simply return “ldapPtr != nil” because ldapPtr can be non-nil when we are not connected if connection fails and unbind fails too. */
	public var isConnected: Bool = false
	
	public init(ldapURL: URL, version: ProtocolVersion, startTLS: Bool, auth: Auth?) {
		self.ldapURL = ldapURL
		self.version = version
		self.startTLS = startTLS
		
		self.auth = auth
	}
	
	deinit {
		if ldapPtr != nil {
			if ldap_unbind_ext_s(ldapPtr, nil, nil) != LDAP_SUCCESS {
				Conf.logger?.warning("LEAKING ldap struct: ldap_unbind failed in connector deinit.")
			}
			ldapPtr = nil
		}
	}
	
	/**
	 Lets the client communicate directly with the LDAP.
	 Use the pointer inside the block only, do **not** store it!
	 
	 - Parameter communicationBlock: The block to execute.
	 - Parameter ldapPtr: An opaque pointer to the underlying LDAP C structure.
	 The structure is opaque in the openldap headers, so we get an opaque pointer in Swift. */
	public func performLDAPCommunication<T>(_ communicationBlock: @Sendable (_ ldapPtr: OpaquePointer) throws -> T) throws -> T {
		guard let ldapPtr else {
			throw Err.notConnected
		}
		return try communicationBlock(ldapPtr)
	}
	
	public func connectIfNeeded() async throws {
		/* TODO: Also check if connection works? */
		guard !isConnected else {
			return
		}
		
		try await connect(())
	}
	
	/* ********************************
	   MARK: - Connector Implementation
	   ******************************** */
	
	public func unqueuedConnect(_: Void) async throws {
		/* As per the LDAP man, we single-thread the init...
		 *
		 * “Note: the first call into the LDAP library also initializes the global options for the library.
		 *  As such the first call should be single-threaded or otherwise protected to insure that only one call is active.
		 *  It is recommended that ldap_get_option() or ldap_set_option() be used in the program's main thread before any additional threads are created.
		 *  See ldap_get_option(3).” */
		let initBlock: @LDAPInitActor (URL, ProtocolVersion, Bool) -> (OpaquePointer?, Error?) = { ldapURL, version, startTLS in
			let ldapPtr: OpaquePointer
			var ldapPtrInit: OpaquePointer? = nil
			let error = ldap_initialize(&ldapPtrInit, ldapURL.absoluteString)
			guard error == LDAP_SUCCESS, let ldapPtrInitNonNil = ldapPtrInit else {
				return (nil, error != LDAP_SUCCESS ? OpenLDAPError(code: error) : Err.internalError)
			}
			ldapPtr = ldapPtrInitNonNil
			
			var v = version.ldapVal
			let error2 = ldap_set_option(ldapPtr, LDAP_OPT_PROTOCOL_VERSION, &v)
			guard error2 == LDAP_OPT_SUCCESS else {
				return (ldapPtr, OpenLDAPError(code: error2))
			}
			
			if startTLS {
				let error = ldap_start_tls_s(ldapPtr, nil, nil)
				guard error == LDAP_SUCCESS else {
					return (ldapPtr, OpenLDAPError(code: error))
				}
			}
			return (ldapPtr, nil)
		}
		
		try await unqueuedDisconnect()
		assert(ldapPtr == nil)
		
		do {
			let (ldapPtrOptional, initError) = await initBlock(ldapURL, version, startTLS)
			ldapPtr = ldapPtrOptional
			
			guard let ldapPtr, initError == nil else {
				throw initError ?? Err.internalError
			}
			
			switch auth {
				case .none:
					(/*nop*/)
					
				case .userPass(username: let username, password: let password):
					guard let cStringPass = password.cString(using: .ascii) else {
						throw Err.passwordIsNotASCII
					}
					
					var cred = berval(bv_len: ber_len_t(strlen(cStringPass)), bv_val: ber_strdup(cStringPass))
					defer {ber_memfree(cred.bv_val)}
					
					/* TODO: <https://twitter.com/CodaFi_/status/1362671988171370496>
					 * Cursed LDAP fact of the day: ldap_sasl_bind(_s) sends a BIND request with the credentials given and nothing more. SASL I/O is not actually installed on the channel even if the bind succeeds. You pretty much always want ldap_sasl_interactive_bind_s - which’ll handle multi-step too.
					 * Why is this cursed? Well, you can (mis)use ldap_sasl_bind(_s) to pretty easily send anonymous - and often cleartext if you forget to instal SSL on the channel - binds. If you hit an old enough install of Active Directory, it just might let you in too! */
					let r = ldap_sasl_bind_s(ldapPtr, username, nil, &cred, nil, nil, nil)
					guard r == LDAP_SUCCESS else {
						throw OpenLDAPError(code: r)
					}
			}
			
			isConnected = true
		} catch {
			_ = try? await unqueuedDisconnect()
			throw error
		}
	}
	
	public func unqueuedDisconnect() async throws {
		guard ldapPtr != nil else {
			assert(!isConnected)
			return
		}
		
		let r = ldap_unbind_ext_s(ldapPtr, nil, nil)
		guard r == LDAP_SUCCESS else {
			throw OpenLDAPError(code: r)
		}
		
		isConnected = false
		ldapPtr = nil
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/** Technically public because it fulfill the HasTaskQueue requirement, but should not be used directly. */
	public var _taskQueue = TaskQueue()
	
	private var ldapPtr: OpaquePointer? /* “LDAP*”; Cannot use the LDAP type (not exported to Swift, because opaque in C headers...) */
	
}
