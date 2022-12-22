/*
 * XCTestCase+Utils.swift
 * CommonForOfficeKitServicesTests
 *
 * Created by François Lamboley on 2022/12/22.
 */

import Foundation
import XCTest



public extension XCTestCase {
	
	static let testsDataPath = URL(fileURLWithPath: #file, isDirectory: false)
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.deletingLastPathComponent()
		.appendingPathComponent("TestsData", isDirectory: true)
//		.appending(path: "TestsData", directoryHint: .isDirectory) /* macOS 13+ */
	
	static func confPath(for name: String) -> URL {
		return testsDataPath
			.appendingPathComponent("confs",   isDirectory: true)
			.appendingPathComponent("private", isDirectory: true)
			.appendingPathComponent(name,      isDirectory: false)
			.appendingPathExtension("json")
	}
	
	static func parsedConf<Conf : Decodable>(for name: String) throws -> Conf {
		let data = try Data(contentsOf: confPath(for: name))
		return try JSONDecoder().decode(Conf.self, from: data)
	}
	
}
