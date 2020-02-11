/*
 * GoogleDriveDoc.swift
 * officectl
 *
 * Created by François Lamboley on 11/02/2020.
 */

import Foundation

import OfficeKit



struct GoogleDriveDoc : Codable {
	
	struct GoogleDriveDocUser : Codable {
		
		var emailAddress: Email?
		var me: Bool?
		var kind: String?
		var displayName: String?
		var photoLink: URL?
		var permissionId: String?
		
	}
	
	var id: String
	var name: String?
	var mimeType: String?
	var originalFilename: String?
	
	var kind: String?
	
	var md5Checksum: String?
	var headRevisionId: String?
	
	var createdTime: Date?
	var modifiedTime: Date?
	
	var isAppAuthorized: Bool?
	
	var ownedByMe: Bool
	var owners: [GoogleDriveDocUser]?
	
	var modifiedByMe: Bool?
	var lastModifyingUser: GoogleDriveDocUser?
	
	var size: String?
	var quotaBytesUsed: String?
	
	var shared: Bool?
	var starred: Bool?
	var viewedByMe: Bool?
	var trashed: Bool?
	var explicitlyTrashed: Bool?
	
	var hasThumbnail: Bool?
	var fileExtension: String?
	var fullFileExtension: String?
	
	var capabilities: [String: Bool]? /* Too lazy to create the Capabilities object… */
	var copyRequiresWriterPermission: Bool?
	var viewersCanCopyContent: Bool?
	var writersCanShare: Bool?
	var permissionIds: [String]?
	
	var iconLink: URL?
	var webViewLink: URL?
	var webContentLink: URL?
	var thumbnailVersion: String?
	var thumbnailLink: URL?
	
	var parents: [String]? /* These are actually parent ids! */
	var spaces: [String]?
	
	var version: String?
	
}
