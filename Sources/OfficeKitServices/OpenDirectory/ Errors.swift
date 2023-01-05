/*
 *  Errors.swift
 * OpenDirectoryOffice
 *
 * Created by François Lamboley on 2022/12/30.
 */

import Foundation

import OfficeKit2



public enum OpenDirectoryOfficeError : Error, Sendable {
	
	case notConnected
	
	case invalidID
	case invalidPersistentID
	
	/* TODO: Maybe (probably) the UserIDType of OpenDirectoryUser is incorrect and should be String (the uid directly). */
	/**
	 The DN returned by the create record operation does not match the one we expected.
	 
	 When creating a user on OpenDirectory, we _cannot_ specify the full DN!
	 We have to only specify the so-called “record name,” which is basically the uid of the DN.
	 So we create the user, then hope for the best… */
	case createdDNDoesNotMatchExpectedDN(createdDN: LDAPDistinguishedName, expectedDN: LDAPDistinguishedName)
	
	case internalError
	
	case __notImplemented
	
}

typealias Err = OpenDirectoryOfficeError
