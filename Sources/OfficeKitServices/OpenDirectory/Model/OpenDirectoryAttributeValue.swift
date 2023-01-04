/*
 * OpenDirectoryAttributeValue.swift
 * OpenDirectoryOffice
 *
 * Created by François Lamboley on 2023/01/03.
 * 
 */

import Foundation

import UnwrapOrThrow



public enum OpenDirectoryAttributeValue : Sendable, Codable {
	
	case string(String)
	case multiString([String])
	case data(Data)
	case multiData([Data])
	
	internal init(any: Any) throws {
		switch any {
			case let str       as  String:  self = .string(str)
			case let multiStr  as [String]: self = .multiString(multiStr)
			case let data      as  Data:    self = .data(data)
			case let multiData as [Data]:   self = .multiData(multiData)
			default: throw Err.internalError
		}
	}
	
	public var asString: String? {
		switch self {
			case let .string(str):       return str
			case let .multiString(strs): return strs.onlyElement
			case let .data(data):        return String(data: data, encoding: .utf8)
			case let .multiData(datas):  return datas.onlyElement.flatMap{ String(data: $0, encoding: .utf8) }
		}
	}
	
	public var asMultiString: [String]? {
		struct NotUTF8 : Error {}
		switch self {
			case let .string(str):       return [str]
			case let .multiString(strs): return strs
			case let .data(data):        return String(data: data, encoding: .utf8).flatMap{ [$0] }
			case let .multiData(datas):  return try? datas.map{ try String(data: $0, encoding: .utf8) ?! NotUTF8() }
		}
	}
	
	public var asData: Data? {
		switch self {
			case let .data(data):        return data
			case let .multiData(datas):  return datas.onlyElement
			case let .string(str):       return Data(str.utf8)
			case let .multiString(strs): return strs.onlyElement.flatMap{ Data($0.utf8) }
		}
	}
	
	public var asMultiData: [Data]? {
		switch self {
			case let .data(data):        return [data]
			case let .multiData(datas):  return datas
			case let .string(str):       return [Data(str.utf8)]
			case let .multiString(strs): return strs.map{ Data($0.utf8) }
		}
	}
	
}
