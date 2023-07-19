/*
 * GoogleDriveFilesList.swift
 * officectl
 *
 * Created by François Lamboley on 2020/02/11.
 */

import Foundation



struct GoogleDriveFilesList : Codable {
	
	var files: [GoogleDriveDoc]?
	
	var kind: String
	var incompleteSearch: Bool
	
	var nextPageToken: String?
	
}
