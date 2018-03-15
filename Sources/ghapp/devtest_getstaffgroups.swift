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
	guard let (accessTokenString, _) = try? rootConfig.superuser.getAccessToken(forScopes: ["https://www.googleapis.com/auth/admin.directory.group", "https://www.googleapis.com/auth/admin.directory.user.readonly"], onBehalfOfUserWithEmail: "francois.lamboley@happn.fr") else {
		devtestGetstaffgroupsCommand.fail(statusCode: 1, errorMessage: "Cannot get access token for admin user")
	}
	
	var getGroupsComponents = URLComponents(string: "https://www.googleapis.com/admin/directory/v1/groups?domain=happn.fr")!
	getGroupsComponents.queryItems = [
		URLQueryItem(name: "domain", value: "happn.fr")
	]
	
	var getGroupsRequest = URLRequest(url: getGroupsComponents.url!)
	getGroupsRequest.addValue("Bearer \(accessTokenString)", forHTTPHeaderField: "Authorization")
	
	guard let (dataO, _) = try? URLSession.shared.synchronousDataTask(with: getGroupsRequest), let data = dataO, let parsedData = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any], let groups = parsedData["groups"] as? [[String: Any]] else {
		devtestGetstaffgroupsCommand.fail(statusCode: 1, errorMessage: "Cannot get groups")
	}
	
	for email in groups.flatMap({ $0["email"] as? String }) {
		if email.hasPrefix("staff.") {print(email)}
	}
}
