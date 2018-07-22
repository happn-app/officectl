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
	
	#if os(Linux)
		/* We can get rid of this when Linux supports keyDecodingStrategy */
		private enum CodingKeys : String, CodingKey {
			case id, nodeId = "node_id"
			case name, fullName = "full_name", description
			case `private`, fork
			case sshUrl = "ssh_url", defaultBranch = "default_branch"
			case /*homepage,*/ topics
			case size, archived
			case hasIssues = "has_issues", hasWiki = "has_wiki", hasPages = "has_pages", hasDownloads = "has_downloads"
			case pushedAt = "pushed_at", createdAt = "created_at", updatedAt = "updated_at"
		}
	#endif
	
}
