/*
 * OpenDirectoryConnector.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/05/2019.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import APIConnectionProtocols
import DirectoryService
import Foundation
import OpenDirectory
import TaskQueue



/* dscl notes:
 *    - Reading the staff-acquisition group on a computer which is not bound to od1.happn.private:
 *         dscl -u diradmin -p od1.happn.private -read /LDAPv3/127.0.0.1/Groups/staff-acquisition
 *      Note: Works either with the diradmin or the happn user.
 *    - Reading the staff-acquisition group on a computer which is bound to od1.happn.private (previous line also works, but this one does not require the password):
 *         dscl /LDAPv3/od1.happn.private -read /Groups/staff-acquisition
 *    - Reading the spotlight user locally:
 *         dscl . -read /Users/spotlight
 *
 * The two first example raise the question: why do we need two passwords in this connector in proxy mode but dscl only requires one?
 * I think it is because it will depend on the operation being done.
 * Reading does not require a password apparently, but the admin pass is required to modify certain fields (I think). */

/* This helps: https://github.com/aosm/OpenDirectory/blob/master/Tests/TestApp.m */
public final actor OpenDirectoryConnector : Connector, HasTaskQueue {
	
	public typealias Scope = Void
	public typealias Authentication = Void
	
	public typealias ProxySettings = (hostname: String, username: String, password: String)
	public typealias CredentialsSettings = (recordType: String, username: String, password: String)
	
	public let sessionOptions: [AnyHashable: Any]?
	
	/* TODO: We may want to let the user choose to instantiate the node with a node type instead of a node name (we used to use ODNodeType(kODNodeTypeAuthentication))… */
	public let nodeName: String
	public let nodeCredentials: CredentialsSettings?
	
	public var currentScope: Void?
	
	public let connectorOperationQueue = SyncOperationQueue(name: "OpenDirectoryConnector")
	
	public init(proxySettings: ProxySettings? = nil, nodeName n: String = "/LDAPv3/127.0.0.1", nodeCredentials creds: CredentialsSettings?) throws {
		sessionOptions = proxySettings.flatMap{ [kODSessionProxyAddress: $0.hostname, kODSessionProxyUsername: $0.username, kODSessionProxyPassword: $0.password] }
		nodeName = n
		nodeCredentials = creds
	}
	
	/**
	 Lets the client communicate directly with the node.
	 Use the node inside the block only, do **not** store it!
	 
	 - Parameter communicationBlock: The block to execute.
	 - Parameter node: The OpenDirectory node.
	 If the connector is not connected, will be `nil`. */
	public func performOpenDirectoryCommunication<T>(_ communicationBlock: (_ node: ODNode?) throws -> T) rethrows -> T {
		/* If I understand the actor principle correctly, it is not possible this function is called twice in parallel,
		 * so there should not be any need for a synchronization queue. */
		return try communicationBlock(node)
	}
	
	/* ********************************
	   MARK: - Connector Implementation
	   ******************************** */
	
	public func unqueuedConnect(scope: Void, auth: Void) async throws {
		try await unqueuedDisconnect()
		
		node = try await withCheckedThrowingContinuation{ continuation in
			DispatchQueue(label: "OpenDirectory Connector Connect Queue").async{continuation.resume(with: Result{
				let session = try ODSession(options: self.sessionOptions)
				let node = try ODNode(session: session, name: self.nodeName)
				if let creds = self.nodeCredentials {
					try node.setCredentialsWithRecordType(creds.recordType, recordName: creds.username, password: creds.password)
				}
				return node
			})}
		}
		currentScope = scope
	}
	
	public func unqueuedDisconnect() async throws {
		currentScope = nil
		node = nil
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/** Technically public because it fulfill the HasTaskQueue requirement, but should not be used directly. */
	public var _taskQueue = TaskQueue()
	
	private var node: ODNode?
	
}

#endif
