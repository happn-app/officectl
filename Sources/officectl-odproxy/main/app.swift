/*
 * app.swift
 * officectl
 *
 * Created by François Lamboley on 2019/07/10.
 */

import Foundation

import CLTLogger
import JSONLogger
import OfficeKit
import Vapor



func app(_ env: Environment) throws -> Application {
	var env = env
	let forcedConfigPath: String?
	if let idx = env.arguments.lastIndex(where: { $0 == "--config-file" }), idx + 1 < env.arguments.count {
		forcedConfigPath = env.arguments[idx+1]
		env.arguments.remove(at: idx)
		env.arguments.remove(at: idx)
	} else {
		forcedConfigPath = nil
	}
	let verbose: Bool
	if let idx = env.arguments.lastIndex(where: { $0 == "--verbose" }) {
		verbose = true
		env.arguments.remove(at: idx)
	} else {
		verbose = false
	}
	
	guard !env.arguments.contains(where: { Set(arrayLiteral: "--config-file", "--verbose").contains($0) }) else {
		throw MessageError(message: "The --config-file or --verbose options can only be specified once. The config-file option requires an argument.")
	}
	
	let factory: (Logger.Level) -> (String) -> LogHandler = {
		switch Environment.get("LOGGER") {
			case "clt": return { level in
				return { label in
					var ret = CLTLogger(multilineMode: .allMultiline, metadataProvider: .init{ ["zz-date": "\(Date())"] })
					ret.metadata = ["zz-label": "\(label)"] /* Note: CLTLogger does not use the label by default so we add it in the metadata. */
					ret.logLevel = level
					return ret
				}
			}
				
			case "json": fallthrough
			default:
				/* We log using json by default because this program is a server and nothing else (there is no reasons to run this in a Terminal directly). */
				return { level in
					return { label in
						var ret = JSONLogger(label: label)
						ret.logLevel = level
						return ret
					}
				}
		}
	}()
	try LoggingSystem.bootstrap(from: &env, factory)
	
	let app = Application(env)
	do    {try configure(app, forcedConfigPath: forcedConfigPath, verbose: verbose)}
	catch {app.shutdown(); throw error}
	
	return app
}
