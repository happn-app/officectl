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
	public let nodeType: ODNodeType
	
	public var currentScope: Void?
	/** The node to use for requests. Non-nil when the connector is connected. */
	private(set) public var node: ODNode?
	
	public let connectorOperationQueue = SyncOperationQueue(name: "OpenDirectoryConnector")
	
	public init(serverHostname h: String, username u: String, password p: String, nodeType t: ODNodeType) throws {
		serverHostname = h
		username = u
		password = p
		nodeType = t
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
					self.node = try ODNode(session: session, type: self.nodeType)
					self.currentScope = scopeToAdd
					handler(nil)
				} catch {
					handler(error)
				}
			}
		}
	}
	
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
