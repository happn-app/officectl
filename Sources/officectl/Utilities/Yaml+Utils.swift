/*
 * Yaml+Utils.swift
 * officectl
 *
 * Created by François Lamboley on 21/03/2019.
 */

import Foundation

import OfficeKit
import Yaml



extension Yaml {
	
	func string(for key: String) throws -> String {
		guard let str = try optionalString(for: key) else {
			throw InvalidArgumentError(message: "Missing value in yaml for key \(key)")
		}
		return str
	}
	
	func optionalString(for key: String) throws -> String? {
		switch self[Yaml.string(key)] {
		case .null:            return nil
		case .string(let str): return str
		default:
			throw InvalidArgumentError(message: "Invalid value (neither absent, null or string) in yaml for key \(key)")
		}
	}
	
	func url(for key: String) throws -> URL {
		let urlStr = try string(for: key)
		guard let url = URL(string: urlStr) else {
			throw InvalidArgumentError(message: "Invalid value (invalid URL) in yaml for key \(key)")
		}
		return url
	}
	
	func arrayOfString(for key: String) throws -> [String] {
		guard let array = try optionalStringArray(for: key) else {
			throw InvalidArgumentError(message: "Missing value in yaml for key \(key)")
		}
		return array
	}
	
	func optionalStringArray(for key: String) throws -> [String]? {
		let value = self[Yaml.string(key)]
		if case .null = value {return nil}
		
		guard let confArray = value.array else {
			throw InvalidArgumentError(message: "Invalid value (not absent or an array) in yaml for key \(key)")
		}
		
		var result = [String]()
		for v in confArray {
			guard let value = v.string else {
				throw InvalidArgumentError(message: "Invalid value in yaml for key \(key) (one of the value is not a string)")
			}
			result.append(value)
		}
		return result
	}
	
	func stringStringDic(for key: String) throws -> [String: String] {
		guard let dic = try optionalStringStringDic(for: key) else {
			throw InvalidArgumentError(message: "Missing value in yaml for key \(key)")
		}
		return dic
	}
	
	func optionalStringStringDic(for key: String) throws -> [String: String]? {
		let value = self[Yaml.string(key)]
		if case .null = value {return nil}
		
		guard let confDic = value.dictionary else {
			throw InvalidArgumentError(message: "Invalid value (not a dictionary) in yaml for key \(key)")
		}
		
		var result = [String: String]()
		for (k, v) in confDic {
			guard let keyStr = k.string else {
				throw InvalidArgumentError(message: "Invalid value in yaml for key \(key) (one of the key is not a string)")
			}
			guard let valueStr = v.string else {
				throw InvalidArgumentError(message: "Invalid value in yaml for key \(key) (one of the value is not a string)")
			}
			result[keyStr] = valueStr
		}
		return result
	}
	
	var stringYamlDic: [String: Yaml]? {
		switch self {
		case .dictionary(let dic):
			var result = [String: Yaml]()
			for (k, v) in dic {
				guard let keyStr = k.string else {return nil}
				result[keyStr] = v
			}
			return result
			
		default:
			return nil
		}
	}
	
	func stringYamlDic(for key: String) throws -> [String: Yaml] {
		guard let dic = try optionalStringYamlDic(for: key) else {
			throw InvalidArgumentError(message: "Missing value in yaml for key \(key)")
		}
		return dic
	}
	
	func optionalStringYamlDic(for key: String) throws -> [String: Yaml]? {
		let value = self[Yaml.string(key)]
		if case .null = value {return nil}
		
		guard let confDic = value.dictionary else {
			throw InvalidArgumentError(message: "Invalid value (not a dictionary) in yaml for key \(key)")
		}
		
		var result = [String: Yaml]()
		for (k, v) in confDic {
			guard let keyStr = k.string else {
				throw InvalidArgumentError(message: "Invalid value in yaml for key \(key) (one of the key is not a string)")
			}
			result[keyStr] = v
		}
		return result
	}
	
	func stringStringYamlDic(for key: String) throws -> [String: [String: Yaml]] {
		guard let dic = try optionalStringStringYamlDic(for: key) else {
			throw InvalidArgumentError(message: "Missing value in yaml for key \(key)")
		}
		return dic
	}
	
	func optionalStringStringYamlDic(for key: String) throws -> [String: [String: Yaml]]? {
		let value = self[Yaml.string(key)]
		if case .null = value {return nil}
		
		guard let confDic = value.dictionary else {
			throw InvalidArgumentError(message: "Invalid value (not a dictionary) in yaml for key \(key)")
		}
		
		var result = [String: [String: Yaml]]()
		for (k, v) in confDic {
			guard let keyStr = k.string else {
				throw InvalidArgumentError(message: "Invalid value in yaml for key \(key) (one of the key is not a string)")
			}
			guard let valueDic = v.stringYamlDic else {
				throw InvalidArgumentError(message: "Invalid value in yaml for key \(key) (one of the value is not a string/yaml dictionary)")
			}
			result[keyStr] = valueDic
		}
		return result
	}
	
}
