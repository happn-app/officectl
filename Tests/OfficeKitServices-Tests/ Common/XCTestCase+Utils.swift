/*
 * XCTestCase+Utils.swift
 * CommonForOfficeKitServicesTests
 *
 * Created by François Lamboley on 2022/12/22.
 */

import Foundation
import XCTest

import StreamReader



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
	
	static func parsedConf<ServiceConf : Decodable, TestConf : Decodable>(for name: String) throws -> (ServiceConf, TestConf) {
		/* Note: We decided to have a two-part conf with a big line separator, but we could’ve had this:
		 * struct FullConf : Decodable {
		 *    var serviceConf: ServiceConf
		 *    var testConf: TestConf
		 * }
		 * and decode the FullConf directly.
		 * Or we could’ve had two different files for the two different confs. */
		let delimiter = "}\n--------------------------------------------------------------------------------\n{"
		let reader = try DataReader(data: Data(contentsOf: confPath(for: name)))
		let part1 = try reader.readData(upTo: [Data(delimiter.utf8)], matchingMode: .anyMatchWins, failIfNotFound: true, includeDelimiter: false).data + Data("}".utf8)
		_ = try reader.readData(size: delimiter.count - 1)
		let part2 = try reader.readDataToEnd()
		
		let decoder = JSONDecoder()
		return try (decoder.decode(ServiceConf.self, from: part1), decoder.decode(TestConf.self, from: part2))
	}
	
}