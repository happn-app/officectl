import Foundation



public extension User {
	
	static func setValueIfNeeded<T : Equatable>(_ val: T, in dest: inout T) -> Bool {
		guard val != dest else {
			return false
		}
		dest = val
		return true
	}
	
	static func setValueIfNeeded<T : Equatable & RawRepresentable>(_ val: T.RawValue, in dest: inout T) -> Bool {
		guard let val = T(rawValue: val) else {
			return false
		}
		guard val != dest else {
			return false
		}
		dest = val
		return true
	}
	
	static func setValueIfNeeded<T : Equatable & RawRepresentable>(_ val: T.RawValue?, in dest: inout T?) -> Bool {
		switch (val, dest) {
			case (nil,      nil): return false
			case (nil,      _  ): dest = nil; return true
			case (let val?, _  ): return setValueIfNeeded(val, in: &dest)
		}
	}
	
	/** If the converter returns nil the conversion has failed. */
	static func setValueIfNeeded<T : Equatable>(_ val: String?, in dest: inout T?, converter: (String) -> T?) -> Bool {
		switch (val, dest) {
			case (nil,      nil): return false
			case (nil,      _  ): dest = nil; return true
			case (let val?, _  ):
				guard let converted = converter(val) else {return false}
				return setValueIfNeeded(converted, in: &dest)
		}
	}
	
}
