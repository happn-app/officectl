/*
 * ApiUser.swift
 * officectl
 *
 * Created by François Lamboley on 01/03/2019.
 */

import Foundation

import OfficeKit



#if false
extension User : Encodable {
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: User.CodingKeys.self)
		
		try container.encode(id, forKey: .id)
		
		try container.encode(distinguishedName, forKey: .ldap_id)
		try container.encode(gitHubId, forKey: .github_id)
		try container.encode(googleUserId, forKey: .google_id)
		
		try container.encode(firstName, forKey: .first_name)
		try container.encode(lastName, forKey: .last_name)
		
		try container.encode(sshKey, forKey: .ssh_key)
	}
	
	private enum CodingKeys: String, CodingKey {
		
		case id
		
		case ldap_id
		case github_id
		case google_id
		
		case first_name
		case last_name
		
		case ssh_key
		
	}
	
}
#endif
