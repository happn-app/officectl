/*
 * Yaml+Utils.swift
 * officectl
 *
 * Created by François Lamboley on 21/03/2019.
 */

import Foundation

import Yaml



extension Yaml : GenericConfig {
	
	public func bool(for key: String, domain: String?) throws -> Bool {
		guard let b = try optionalBool(for: key, domain: domain) else {
			throw ConfigError(domain: domain, key: key, message: "Missing value in yaml")
		}
		return b
	}
	
	public func optionalBool(for key: String, domain: String?) throws -> Bool? {
		switch self[Yaml.string(key)] {
		case .null:        return nil
		case .bool(let b): return b
		default:
			throw ConfigError(domain: domain, key: key, message: "Invalid value (neither absent, null or bool) in yaml")
		}
	}
	
	public func int(for key: String, domain: String?) throws -> Int {
		guard let i = try optionalInt(for: key, domain: domain) else {
			throw ConfigError(domain: domain, key: key, message: "Missing value in yaml")
		}
		return i
	}
	
	public func optionalInt(for key: String, domain: String?) throws -> Int? {
		switch self[Yaml.string(key)] {
		case .null:       return nil
		case .int(let i): return i
		default:
			throw ConfigError(domain: domain, key: key, message: "Invalid value (neither absent, null or int) in yaml")
		}
	}
	
	public func string(for key: String, domain: String?) throws -> String {
		guard let str = try optionalString(for: key, domain: domain) else {
			throw ConfigError(domain: domain, key: key, message: "Missing value in yaml")
		}
		return str
	}
	
	public func optionalString(for key: String, domain: String?) throws -> String? {
		switch self[Yaml.string(key)] {
		case .null:            return nil
		case .string(let str): return str
		default:
			throw ConfigError(domain: domain, key: key, message: "Invalid value (neither absent, null or string) in yaml")
		}
	}
	
	public func url(for key: String, domain: String?) throws -> URL {
		guard let url = try optionalURL(for: key, domain: domain) else {
			throw ConfigError(domain: domain, key: key, message: "Missing value in yaml")
		}
		return url
	}
	
	public func optionalURL(for key: String, domain: String?) throws -> URL? {
		guard let urlStr = try optionalString(for: key, domain: domain) else {return nil}
		guard let url = URL(string: urlStr) else {
			throw ConfigError(domain: domain, key: key, message: "Invalid value (invalid URL) in yaml")
		}
		return url
	}

	public func stringArray(for key: String, domain: String?) throws -> [String] {
		guard let array = try optionalStringArray(for: key, domain: domain) else {
			throw ConfigError(domain: domain, key: key, message: "Missing value in yaml")
		}
		return array
	}
	
	public func optionalStringArray(for key: String, domain: String?) throws -> [String]? {
		let value = self[Yaml.string(key)]
		if case .null = value {return nil}
		
		guard let confArray = value.array else {
			throw ConfigError(domain: domain, key: key, message: "Invalid value (not absent or an array) in yaml")
		}
		
		var result = [String]()
		for v in confArray {
			guard let value = v.string else {
				throw ConfigError(domain: domain, key: key, message: "Invalid value in yaml (one of the value is not a string)")
			}
			result.append(value)
		}
		return result
	}
	
	public func stringStringDic(for key: String, domain: String?) throws -> [String: String] {
		guard let dic = try optionalStringStringDic(for: key, domain: domain) else {
			throw ConfigError(domain: domain, key: key, message: "Missing value in yaml")
		}
		return dic
	}
	
	public func optionalStringStringDic(for key: String, domain: String?) throws -> [String: String]? {
		let value = self[Yaml.string(key)]
		if case .null = value {return nil}
		
		guard let confDic = value.dictionary else {
			throw ConfigError(domain: domain, key: key, message: "Invalid value (not a dictionary) in yaml")
		}
		
		var result = [String: String]()
		for (k, v) in confDic {
			guard let keyStr = k.string else {
				throw ConfigError(domain: domain, key: key, message: "Invalid value in yaml (one of the key is not a string)")
			}
			guard let valueStr = v.string else {
				throw ConfigError(domain: domain, key: key, message: "Invalid value in yaml (value for key \"\(keyStr)\" is not a string)")
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
			throw ConfigError(domain: domain, key: key, message: "Missing value in yaml")
		}
		return dic
	}
	
	public func optionalStringGenericConfigDic(for key: String, domain: String?) throws -> [String: GenericConfig]? {
		let value = self[Yaml.string(key)]
		if case .null = value {return nil}
		
		guard let confDic = value.dictionary else {
			throw ConfigError(domain: domain, key: key, message: "Invalid value (not a dictionary) in yaml")
		}
		
		var result = [String: Yaml]()
		for (k, v) in confDic {
			guard let keyStr = k.string else {
				throw ConfigError(domain: domain, key: key, message: "Invalid value in yaml (one of the key is not a string)")
			}
			result[keyStr] = v
		}
		return result
	}
	
	public func genericConfig(for key: String, domain: String?) throws -> GenericConfig {
		guard let dic = try optionalGenericConfig(for: key, domain: domain) else {
			throw ConfigError(domain: domain, key: key, message: "Missing value in yaml")
		}
		return dic
	}
	
	public func optionalGenericConfig(for key: String, domain: String?) throws -> GenericConfig? {
		let value = self[Yaml.string(key)]
		if case .null = value {return nil}
		return value
	}
	
	public func asString(domain: String?) throws -> String {
		guard let str = string else {
			throw ConfigError(domain: domain, key: "self", message: "Value is not a String")
		}
		return str
	}
	
	public func asStringArray(domain: String?) throws -> [String] {
		guard let a = try array?.map({ try $0.asString(domain: domain) }) else {
			throw ConfigError(domain: domain, key: "self", message: "Value is not an array")
		}
		return a
	}
	
}
