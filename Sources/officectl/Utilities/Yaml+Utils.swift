/*
 * Yaml+Utils.swift
 * officectl
 *
 * Created by François Lamboley on 21/03/2019.
 */

import Foundation

import OfficeKit
import Yaml



extension Yaml : GenericConfig {
	
	public func string(for key: String, domain: String?) throws -> String {
		guard let str = try optionalString(for: key, domain: domain) else {
			throw InvalidArgumentError(message: "Missing value in yaml for key \(key)")
		}
		return str
	}
	
	public func optionalString(for key: String, domain: String?) throws -> String? {
		switch self[Yaml.string(key)] {
		case .null:            return nil
		case .string(let str): return str
		default:
			throw InvalidArgumentError(message: "Invalid value (neither absent, null or string) in yaml for key \(key)")
		}
	}
	
	public func url(for key: String, domain: String?) throws -> URL {
		guard let url = try optionalURL(for: key, domain: domain) else {
			throw InvalidArgumentError(message: "Missing value in yaml for key \(key)")
		}
		return url
	}
	
	public func optionalURL(for key: String, domain: String?) throws -> URL? {
		guard let urlStr = try optionalString(for: key, domain: domain) else {return nil}
		guard let url = URL(string: urlStr) else {
			throw InvalidArgumentError(message: "Invalid value (invalid URL) in yaml for key \(key)")
		}
		return url
	}

	public func arrayOfString(for key: String, domain: String?) throws -> [String] {
		guard let array = try optionalStringArray(for: key, domain: domain) else {
			throw InvalidArgumentError(message: "Missing value in yaml for key \(key)")
		}
		return array
	}
	
	public func optionalStringArray(for key: String, domain: String?) throws -> [String]? {
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
	
	public func stringStringDic(for key: String, domain: String?) throws -> [String: String] {
		guard let dic = try optionalStringStringDic(for: key, domain: domain) else {
			throw InvalidArgumentError(message: "Missing value in yaml for key \(key)")
		}
		return dic
	}
	
	public func optionalStringStringDic(for key: String, domain: String?) throws -> [String: String]? {
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
	
	public func stringGenericConfigDic(for key: String, domain: String?) throws -> [String: GenericConfig] {
		guard let dic = try optionalStringGenericConfigDic(for: key, domain: domain) else {
			throw InvalidArgumentError(message: "Missing value in yaml for key \(key)")
		}
		return dic
	}
	
	public func optionalStringGenericConfigDic(for key: String, domain: String?) throws -> [String: GenericConfig]? {
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
	
	public func genericConfig(for key: String, domain: String?) throws -> GenericConfig {
		guard let dic = try optionalGenericConfig(for: key, domain: domain) else {
			throw InvalidArgumentError(message: "Missing value in yaml for key \(key)")
		}
		return dic
	}
	
	public func optionalGenericConfig(for key: String, domain: String?) throws -> GenericConfig? {
		let value = self[Yaml.string(key)]
		if case .null = value {return nil}
		return value
	}
	
}
