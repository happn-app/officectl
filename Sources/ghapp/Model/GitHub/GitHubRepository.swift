/*
 * GitHubRepository.swift
 * ghapp
 *
 * Created by François Lamboley on 27/06/2018.
 */

import Foundation



struct GitHubRepository : Codable {
	
	var id: Int
	var nodeId: String
	
	var name: String
	var fullName: String
	var description: String?
	
	var `private`: Bool
	var fork: Bool
	
	var sshUrl: URL
	var defaultBranch: String?
	
//	var homepage: URL?
	var topics: [String]?
	
	var size: Int
	var archived: Bool
	
	var hasIssues: Bool
	var hasWiki: Bool
	var hasPages: Bool
	var hasDownloads: Bool
	
	var pushedAt: Date?
	var createdAt: Date
	var updatedAt: Date?
	
}
