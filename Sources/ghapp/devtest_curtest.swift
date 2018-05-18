import Guaka
import Foundation


let devtestCurtestCommand = Command(
	usage: "curtest", configuration: configuration, run: execute
)

private func configuration(command: Command) {
	command.add(
		flags: [
		]
	)
}

private func execute(command: Command, flags: Flags, args: [String]) {
	guard let token = try? rootConfig.superuser.getAccessToken(forScopes: ["https://www.googleapis.com/auth/admin.directory.group", "https://www.googleapis.com/auth/admin.directory.user.readonly"], onBehalfOfUserWithEmail: rootConfig.adminEmail) else {
		gettokenCommand.fail(statusCode: 2, errorMessage: "Cannot get token")
	}
	
	let defaultError = NSError(domain: "Superuser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got an error"])
	let originalMLsAndContent = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: "/Users/frizlab/Desktop/ref_lists_before_didier_hack.txt", isDirectory: false)), options: []) as! [String: [String]]
	
	for (mlId, mails) in originalMLsAndContent {
		do {
			/* Removing Karima from MLs */
			let urlComponents = URLComponents(string: "https://www.googleapis.com/admin/directory/v1/groups/\(mlId)/members")!
			
			var request = URLRequest(url: urlComponents.url!)
			request.addValue("Bearer \(token.0)", forHTTPHeaderField: "Authorization")
			request.httpMethod = "GET"
			
			try URLSession.shared.fetchAllPages(baseRequest: request, errorToRaise: defaultError){ json in
				guard let members = json["members"] as? [[String: String]] else {return}
				for member in members {
					guard let id = member["id"], let email = member["email"], email.starts(with: "karima.ben-abdelmalek@happn.") else {continue}
					
					var request = URLRequest(url: URL(string: "https://www.googleapis.com/admin/directory/v1/groups/\(mlId)/members/\(id)")!)
					request.addValue("Bearer \(token.0)", forHTTPHeaderField: "Authorization")
					request.httpMethod = "DELETE"
					
					_ = try URLSession.shared.synchronousDataTask(with: request)
				}
			}
			
			/* Add original members in MLs */
			for mail in mails {
				let urlComponents = URLComponents(string: "https://www.googleapis.com/admin/directory/v1/groups/\(mlId)/members")!
				
				var request = URLRequest(url: urlComponents.url!)
				request.addValue("Bearer \(token.0)", forHTTPHeaderField: "Authorization")
				request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
				request.httpMethod = "POST"
				
				request.httpBody = try! JSONSerialization.data(withJSONObject: ["email": mail, "role": "MEMBER"], options: [])
				
				if URLSession.shared.fetchJSON(request: request) == nil {
					print("Got error for mail \(mail), ML id \(mlId)")
				}
			}
		} catch {
			print("\"error\": \"¡¡¡Got error \(error) for mailing list id \(mlId)!!!\"")
		}
	}
}

/*
private func execute(command: Command, flags: Flags, args: [String]) {
	guard let token = try? rootConfig.superuser.getAccessToken(forScopes: ["https://www.googleapis.com/auth/admin.directory.group", "https://www.googleapis.com/auth/admin.directory.user.readonly"], onBehalfOfUserWithEmail: rootConfig.adminEmail) else {
		gettokenCommand.fail(statusCode: 2, errorMessage: "Cannot get token")
	}

	let defaultError = NSError(domain: "Superuser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got an error"])
	let mailinglistids = ["00vx12271fgqpn6", "014ykbeg223h7c0", "03ygebqi1udkrns", "04h042r0496k33f", "02dlolyb3waz1fq", "01v1yuxt2patinz", "03tbugp11g65aa5", "03q5sasy20slrob", "01302m920mfm23f", "019c6y1847ovshm", "02s8eyo10qo9sql", "00z337ya1rhsfoo", "02w5ecyt1g8db4i", "03tbugp12m9brqt", "00kgcv8k0kda00v", "028h4qwu31gwz0p", "035nkun20vnh6rl", "02w5ecyt0j31oog", "0319y80a20n5g4g", "03jtnz0s3d231a4", "01mrcu091ggm4ma", "00nmf14n2nvx57p", "034g0dwd3t8f6ic", "0147n2zr4div40x", "04h042r04jude9c", "03l18frh3w1fq8e", "03ep43zb120kl78", "04k668n32z3dfpf", "02szc72q1fnz8pj", "02jxsxqh3jbf8ei", "048pi1tg2con23m", "043ky6rz3h7pxnx", "0147n2zr2uo3rwo", "03ygebqi4b3pkrj", "03l18frh3ntadb7", "026in1rg19lu3ly", "00zu0gcz0vpnt62", "01v1yuxt2qs5ff8", "00meukdy2i4rwr8", "026in1rg3ro1u58", "034g0dwd0hbb80p"]

	/* *** Retrieve Ref MLs Contents *** */
//	print("[")
//	var firstML = true
//	for mailinglistid in mailinglistids {
//		do {
//			print((firstML ? "" : ",") + "{\"\(mailinglistid)\": [")
//			let urlComponents = URLComponents(string: "https://www.googleapis.com/admin/directory/v1/groups/\(mailinglistid)/members")!
//
//			var request = URLRequest(url: urlComponents.url!)
//			request.addValue("Bearer \(token.0)", forHTTPHeaderField: "Authorization")
//			request.httpMethod = "GET"
//
//			var first = true
//			try URLSession.shared.fetchAllPages(baseRequest: request, errorToRaise: defaultError){ json in
//				guard let members = json["members"] as? [[String: String]] else {return}
//				for member in members {
//					member["email"].flatMap{ print((first ? "" : ",") + "\"\($0)\"") }
//					first = false
//				}
//			}
//			print("]}")
//			firstML = false
//		} catch {
//			print("\"error\": \"¡¡¡Got error \(error) for mailing list id \(mailinglistid)!!!\"")
//		}
//	}
//	print("]")

	/* *** Add Karima *** */
//	for mailinglistid in mailinglistids {
//		do {
//			let urlComponents = URLComponents(string: "https://www.googleapis.com/admin/directory/v1/groups/\(mailinglistid)/members")!
//
//			var request = URLRequest(url: urlComponents.url!)
//			request.addValue("Bearer \(token.0)", forHTTPHeaderField: "Authorization")
//			request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
//			request.httpMethod = "POST"
//
//			request.httpBody = try! JSONSerialization.data(withJSONObject: ["email": "karima.ben-abdelmalek@happn.fr", "role": "MEMBER"], options: [])
//
//			guard URLSession.shared.fetchJSON(request: request) != nil else {
//				throw defaultError
//			}
//		} catch {
//			print("¡¡¡Got error \(error) for mailing list id \(mailinglistid)!!!\"")
//		}
//	}

	/* *** Remove Everyone But Karima *** */
//	for mailinglistid in mailinglistids {
//		do {
//			let urlComponents = URLComponents(string: "https://www.googleapis.com/admin/directory/v1/groups/\(mailinglistid)/members")!
//
//			var request = URLRequest(url: urlComponents.url!)
//			request.addValue("Bearer \(token.0)", forHTTPHeaderField: "Authorization")
//			request.httpMethod = "GET"
//
//			try URLSession.shared.fetchAllPages(baseRequest: request, errorToRaise: defaultError){ json in
//				guard let members = json["members"] as? [[String: String]] else {return}
//				for member in members {
//					guard let id = member["id"], let email = member["email"], email != "karima.ben-abdelmalek@happn.fr" else {continue}
//
//					var request = URLRequest(url: URL(string: "https://www.googleapis.com/admin/directory/v1/groups/\(mailinglistid)/members/\(id)")!)
//					request.addValue("Bearer \(token.0)", forHTTPHeaderField: "Authorization")
//					request.httpMethod = "DELETE"
//
//					_ = try URLSession.shared.synchronousDataTask(with: request)
//				}
//			}
//		} catch {
//			print("¡¡¡Got error \(error) for mailing list id \(mailinglistid)!!!")
//		}
//	}
}*/
