import Foundation

import GenericJSON



public extension User {
	
	func oU_valueForProperty(_ property: UserProperty) -> Any? {
		switch property {
			case .id:           return oU_id
			case .persistentID: return oU_persistentID
			case .isSuspended:  return oU_isSuspended
			case .firstName:    return oU_firstName
			case .lastName:     return oU_lastName
			case .nickname:     return oU_nickname
			case .emails:       return oU_emails
			default:
				assert(!property.isStandard)
				return oU_valueForNonStandardProperty(property.rawValue)
		}
	}
	
	/** Returns the properties that were _modified_. */
	@discardableResult
	mutating func oU_applyHints(_ hints: [UserProperty: (any Sendable)?], convertMismatchingTypes convert: Bool) -> Set<UserProperty> {
		return Set(hints.compactMap{ kv in
			oU_setValue(kv.value, forProperty: kv.key, convertMismatchingTypes: convert).propertyWasModified ? kv.key : nil
		})
	}
	
}


public extension User {
	
	/* Note: We avoid name overload in these function because the type system could use the optional method when the required is expected and it would be invisible at the call site. */
	
	/** If the converter returns nil the conversion has failed. */
	static func setOptionalProperty<T : Equatable, U>(_ dest: inout T?, to val: U?, allowTypeConversion convert: Bool, converter: (U) -> T?) -> PropertyChangeResult {
		switch (val, dest) {
			case (nil,      nil):             return .successUnchanged
			case (nil,      _  ): dest = nil; return .successChanged
			case (let val?, _  ):
				do    {return setProperty(&dest, to: try Converters.convertPropertyValue(val, allowTypeConversion: convert, converter: converter)) ? .successChanged : .successUnchanged}
				catch {return .anyFailure(error)}
		}
	}
	
	/** If the converter returns nil the conversion has failed. */
	static func setProperty<T : Equatable, U>(_ dest: inout T, to val: U?, allowTypeConversion convert: Bool, converter: (U) -> T?) -> PropertyChangeResult {
		do {
			guard let val else {throw PropertyChangeResult.Failure.unremovableProperty}
			return setProperty(&dest, to: try Converters.convertPropertyValue(val, allowTypeConversion: convert, converter: converter)) ? .successChanged : .successUnchanged
		} catch {
			return .anyFailure(error)
		}
	}
	
	static func setProperty<T : Equatable>(_ dest: inout T, to val: T) -> Bool {
		guard val != dest else {
			return false
		}
		dest = val
		return true
	}
	
}


public extension User {
	
	/**
	 Returns the full name computed from first name and last name, whether full name is set or not.
	 If there are no first name nor last name, we return a static string. */
	var computedFullName: String {
		let firstAndLastName = [oU_firstName, oU_lastName].compactMap{ $0 }
		guard !firstAndLastName.isEmpty else {
			return "<Unknown Name>"
		}
		return firstAndLastName.joined(separator: " ")
	}
	
}
