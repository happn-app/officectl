/*
 * ODRecord+DirectoryUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 02/07/2019.
 */

#if canImport(DirectoryService) && canImport(OpenDirectory)

import Foundation
import OpenDirectory



extension ODRecord : DirectoryUser {
	
	public typealias IdType = String
	
	public var id: String {
		/* One of my best and safest line is here. But I don’t really care, it’s
		 * OpenDirectory, this Framework is an aberration…
		 * To be fully honest, IIUC, the ODRecord type in theory cannot be a
		 * DirectoryUser, because it is simply a wrapper to something making
		 * requests on the underlying directory. I might be wrong. */
		return try! (recordDetails(forAttributes: [kODAttributeTypeMetaRecordName])[kODAttributeTypeMetaRecordName] as! [String]).first!
	}
	
	public var emails: RemoteProperty<[Email]> {
		#warning("TODO")
		return .unfetched
	}
	
	public var firstName: RemoteProperty<String?> {
		#warning("TODO")
		return .unfetched
	}
	
	public var lastName: RemoteProperty<String?> {
		#warning("TODO")
		return .unfetched
	}
	
	public var nickname: RemoteProperty<String?> {
		return .unsupported
	}
	
}

#endif
