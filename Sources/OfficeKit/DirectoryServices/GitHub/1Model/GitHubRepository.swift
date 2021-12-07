/*
 * GitHubRepository.swift
 * officectl
 *
 * Created by François Lamboley on 27/06/2018.
 */

import Foundation



public struct GitHubRepository : Codable {
	
	public var id: Int
	public var nodeId: String
	
	public var name: String
	public var fullName: String
	public var description: String?
	
	public var `private`: Bool
	public var fork: Bool
	
	public var sshUrl: URL
	public var defaultBranch: String?
	
//	public var homepage: URL?
	public var topics: [String]?
	
	public var size: Int
	public var archived: Bool
	
	public var hasIssues: Bool
	public var hasWiki: Bool
	public var hasPages: Bool
	public var hasDownloads: Bool
	
	public var pushedAt: Date?
	public var createdAt: Date
	public var updatedAt: Date?
	
}
