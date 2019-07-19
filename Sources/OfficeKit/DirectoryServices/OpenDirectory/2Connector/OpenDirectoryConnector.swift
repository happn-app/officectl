/*
 * OpenDirectoryConnector.swift
 * OfficeKit
 *
 * Created by François Lamboley on 20/05/2019.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import DirectoryService
import Foundation
import OpenDirectory



/* This helps: https://github.com/aosm/OpenDirectory/blob/master/Tests/TestApp.m */
public final class OpenDirectoryConnector : Connector {
	
	public typealias ScopeType = Void
	
	public let serverHostname: String
	public let username: String
	public let password: String
	public let nodeName: String?
	
	public var currentScope: Void?
	
	public let connectorOperationQueue = SyncOperationQueue(name: "OpenDirectoryConnector")
	
	public init(serverHostname h: String, username u: String, password p: String, nodeName n: String?) throws {
		serverHostname = h
		username = u
		password = p
		nodeName = n
	}
	
	/** Lets the client communicate directly with the node. Use the node inside
	the block only, do **not** store it!
	
	- Parameter communicationBlock: The block to execute.
	- Parameter node: The OpenDirectory node. If the connector is not connected,
	will be `nil`. */
	public func performOpenDirectoryCommunication<T>(_ communicationBlock: (_ node: ODNode?) throws -> T) rethrows -> T {
		return try odCommunicationQueue.sync{ try communicationBlock(node) }
	}
	
	/* ********************************
	   MARK: - Connector Implementation
	   ******************************** */
	
	public func unsafeChangeCurrentScope(changeType: ChangeScopeOperationType<Void>, handler: @escaping (Error?) -> Void) {
		switch changeType {
		case .remove, .removeAll:
			currentScope = nil
			node = nil
			handler(nil)
			return
			
		case .add(let scopeToAdd):
			guard currentScope == nil else {
				handler(InvalidArgumentError(message: "Cannot add a scope for the OpenDirectory connector."))
				return
			}
			
			DispatchQueue(label: "OpenDirectory Connector Connect Queue").async{
				do {
					let session = try ODSession(options: [
						kODSessionProxyAddress: self.serverHostname,
						kODSessionProxyUsername: self.username,
						kODSessionProxyPassword: self.password
					])
					self.node = try ODNode(session: session, name: self.nodeName)
					self.currentScope = scopeToAdd
					handler(nil)
				} catch {
					handler(error)
				}
			}
		}
	}
	
	private let odCommunicationQueue = DispatchQueue(label: "OpenDirectory Communication Queue")
	private var node: ODNode?
	
}


public final class OpenDirectoryRecordAuthenticator : Authenticator {
	
	public typealias RequestType = ODRecord
	
	public let username: String
	public let password: String
	
	public init(username u: String, password p: String) throws {
		username = u
		password = p
	}
	
	public func authenticate(request: ODRecord, handler: @escaping (Result<ODRecord, Error>, Any?) -> Void) {
		DispatchQueue(label: "OpenDirectory Record Authenticator Queue").async{
			do {
				try request.setNodeCredentials(self.username, password: self.password)
				handler(.success(request), nil)
			} catch {
				handler(.failure(error), nil)
			}
		}
	}
	
}

#endif
