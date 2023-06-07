/*
 * OpenDirectoryConnector.swift
 * OpenDirectoryOffice
 *
 * Created by François Lamboley on 2023/01/02.
 */

import Foundation
import OpenDirectory

import APIConnectionProtocols
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

/* This helped: <https://github.com/aosm/OpenDirectory/blob/master/Tests/TestApp.m>
 * This was interesting also <https://stackoverflow.com/a/69122631>,
 *  mostly for some info on what is the /Search node,
 *  aka. almost always (don’t know of a case when it’s not true),
 *  the node with type kODNodeTypeAuthentication. */
public final actor OpenDirectoryConnector : Connector, HasTaskQueue {
	
	public typealias Authentication = Void
	
	public struct ProxySettings : Sendable, Codable {
		
		public var hostname: String
		public var username: String
		public var password: String
		
	}
	
	public enum NodeType : Sendable, Codable {
		
		case nodeType(ODNodeType)
		case nodeName(String)
		
	}
	
	public enum NodeCredentials : Sendable, Codable {
		
		case user(username: String, password: String)
		
	}
	
	public let nodeType: NodeType
	public let nodeCredentials: NodeCredentials?
	
	public let sessionOptions: [String: Sendable]?
	
	/* We cannot use “_node.wrappedValue != nil” because “_node” is on another actor context. */
	public var isConnected: Bool = false
	
	public init(proxySettings: ProxySettings? = nil, nodeType: NodeType = .nodeName("/LDAPv3/127.0.0.1"), nodeCredentials: NodeCredentials?) {
		self.sessionOptions = proxySettings.flatMap{ [
			kODSessionProxyAddress!  as String: $0.hostname,
			kODSessionProxyUsername! as String: $0.username,
			kODSessionProxyPassword! as String: $0.password
		] }
		self.nodeType = nodeType
		self.nodeCredentials = nodeCredentials
	}
	
	public func connectIfNeeded() async throws {
		guard !isConnected else {
			return
		}
		
		try await connect(())
	}
	
	/**
	 Lets the client communicate directly with the node.
	 Use the node inside the block only, do **not** store it!
	 
	 - Parameter communicationBlock: The block to execute.
	 - Parameter node: The OpenDirectory node. */
	public func performOpenDirectoryCommunication<T : Sendable>(_ communicationBlock: @ODActor @Sendable (_ node: ODNode) throws -> T) async throws -> T {
		return try await _node.perform{ node in
			guard let node else {
				throw Err.notConnected
			}
			
			return try communicationBlock(node)
		}
	}
	
	/* ********************************
	   MARK: - Connector Implementation
	   ******************************** */
	
	public func unqueuedConnect(_: Void) async throws {
		try await unqueuedDisconnect()
		
		try await _node.perform{ wrappedNode in
			let session = try ODSession(options: self.sessionOptions)
			let node: ODNode
			switch self.nodeType {
				case let .nodeType(type): node = try ODNode(session: session, type: type)
				case let .nodeName(name): node = try ODNode(session: session, name: name)
			}
			switch self.nodeCredentials {
				case .none: (/*nop*/)
				case let .user(username: username, password: password):
					try node.setCredentialsWithRecordType(kODRecordTypeUsers, recordName: username, password: password)
			}
			wrappedNode = node
		}
		isConnected = true
	}
	
	public func unqueuedDisconnect() async throws {
		isConnected = false
		await _node.perform{ $0 = nil }
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/** Technically public because it fulfill the `HasTaskQueue` requirement, but should not be used directly. */
	public var _taskQueue = TaskQueue()
	
	/* Not using the wrapper as a property wrapper or the init becomes mysteriously isolated to @ODActor… */
	private var _node: ODObjectWrapper<ODNode> = .init()
	
}
