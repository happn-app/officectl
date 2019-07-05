/*
 * GitHubUser.swift
 * OfficeKit
 *
 * Created by François Lamboley on 02/07/2019.
 */

import Foundation



public struct GitHubUser : DirectoryUser {
	
	public typealias IdType = String
	
	public var id: String
	
	public var emails: RemoteProperty<[Email]>
	
	public var firstName: RemoteProperty<String?>
	public var lastName: RemoteProperty<String?>
	public var nickname: RemoteProperty<String?>
	
}
