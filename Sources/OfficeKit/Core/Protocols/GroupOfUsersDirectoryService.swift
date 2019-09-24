/*
 * GroupOfUsersDirectoryService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/09/2019.
 */

import Foundation

import Async
import GenericJSON
import Service



public protocol GroupOfUsersDirectoryService : UserDirectoryService {
	
	associatedtype GroupType : DirectoryGroup
	
}
