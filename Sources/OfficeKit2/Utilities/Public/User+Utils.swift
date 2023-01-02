import Foundation



public extension User {
	
	/* Note: We avoid name overload in these function because the type system could use the optional method when the required is expected and it would be invisible at the call site. */
	
	/** If the converter returns nil the conversion has failed. */
	static func setValueIfNeeded<T : Equatable, U>(_ val: U?, in dest: inout T?, converter: (U) -> T?) -> Bool {
		switch (val, dest) {
			case (nil,      nil): return false
			case (nil,      _  ): dest = nil; return true
			case (let val?, _  ):
				guard let converted = converter(val) else {return false}
				return setRequiredValueSameTypeIfNeeded(converted, in: &dest)
		}
	}
	
	/** If the converter returns nil the conversion has failed. */
	static func setRequiredValueIfNeeded<T : Equatable, U>(_ val: U, in dest: inout T, converter: (U) -> T?) -> Bool {
		guard let converted = converter(val) else {return false}
		return setRequiredValueSameTypeIfNeeded(converted, in: &dest)
	}
	
	static func setRequiredValueSameTypeIfNeeded<T : Equatable>(_ val: T, in dest: inout T) -> Bool {
		guard val != dest else {
			return false
		}
		dest = val
		return true
	}
	
}
