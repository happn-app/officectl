/*
 * GoogleDriveFilesList.swift
 * officectl
 *
 * Created by François Lamboley on 11/02/2020.
 */

import Foundation



struct GoogleDriveFilesList : Codable {
	
	var files: [GoogleDriveDoc]?
	
	var kind: String
	var incompleteSearch: Bool
	
	var nextPageToken: String?
	
}
