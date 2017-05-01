import Guaka
import Foundation


let devtestGmailapiCommand = Command(
	usage: "gmailapi", configuration: configuration, run: execute
)

private func configuration(command: Command) {
	command.add(
		flags: [
		]
	)
}

private func execute(flags: Flags, args: [String]) {
	guard let user = (try? rootConfig.superuser.retrieveUsers(using: "francois.lamboley@happn.fr", with: ["happn.fr"], contrainedTo: ["francois.lamboley@happn.fr"], verbose: true))?.first else {
		devtestGmailapiCommand.fail(statusCode: 1, errorMessage: "Cannot get tested user")
	}
	guard let accessTokenString = (try? user.accessToken(forScopes: ["https://mail.google.com/"], withSuperuser: rootConfig.superuser, forceRegeneration: false))?.0 else {
		devtestGmailapiCommand.fail(statusCode: 1, errorMessage: "Cannot get access token for tested user")
	}
	
	var getMessagesComponents = URLComponents(string: "https://www.googleapis.com/gmail/v1/users/\(user.id)/messages")!
	getMessagesComponents.queryItems = [
		URLQueryItem(name: "includeSpamTrash", value: "true"),
		URLQueryItem(name: "maxResults", value: "500")
	]
	
	var getMessagesRequet = URLRequest(url: getMessagesComponents.url!)
	getMessagesRequet.addValue("Bearer \(accessTokenString)", forHTTPHeaderField: "Authorization")
	
	guard let (dataO, _) = try? URLSession.shared.synchronousDataTask(with: getMessagesRequet), let data = dataO, let parsedData = try? JSONSerialization.jsonObject(with: data, options: []) else {
		devtestGmailapiCommand.fail(statusCode: 1, errorMessage: "Cannot get tested user messages")
	}
	
	/* The returned message dictionaries contains only the message id and the
	 * thread id of the message. To get more info, one have to get the messages
	 * specifically (one API call per message ><). */
	print(parsedData)
}
