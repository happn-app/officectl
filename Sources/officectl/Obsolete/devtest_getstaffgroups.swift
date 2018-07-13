/*
 * devtest_getstaffgroups.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Guaka
import Foundation


let devtestGetstaffgroupsCommand = Command(
	usage: "getstaffgroups", configuration: configuration, run: execute
)

private func configuration(command: Command) {
	command.add(
		flags: [
		]
	)
}

private func execute(command: Command, flags: Flags, args: [String]) {
//	guard let (accessTokenString, _) = try? rootConfig.superuser.getAccessToken(forScopes: ["https://www.googleapis.com/auth/admin.directory.group", "https://www.googleapis.com/auth/admin.directory.user.readonly"], onBehalfOfUserWithEmail: rootConfig.adminEmail) else {
//		devtestGetstaffgroupsCommand.fail(statusCode: 1, errorMessage: "Cannot get access token for admin user")
//	}

//	var getGroupsComponents = URLComponents(string: "https://www.googleapis.com/admin/directory/v1/groups?domain=happn.fr")!
//	getGroupsComponents.queryItems = [
//		URLQueryItem(name: "domain", value: "happn.fr")
//	]

//	var getGroupsRequest = URLRequest(url: getGroupsComponents.url!)
//	getGroupsRequest.addValue("Bearer \(accessTokenString)", forHTTPHeaderField: "Authorization")

//	guard let parsedData = URLSession.shared.fetchJSON(request: getGroupsRequest), let groups = parsedData["groups"] as? [[String: Any?]] else {
//		devtestGetstaffgroupsCommand.fail(statusCode: 1, errorMessage: "Cannot get groups")
//	}

//	for email in groups.compactMap({ $0["email"] as? String }) {
//		if email.hasPrefix("staff.") {print(email)}
//	}
}
