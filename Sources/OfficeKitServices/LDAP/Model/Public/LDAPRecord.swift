/*
 * LDAPRecord.swift
 * LDAPOffice
 *
 * Created by François Lamboley on 2023/01/06.
 */

import Foundation

import UnwrapOrThrow

import OfficeKit2



public typealias LDAPRecord = [LDAPObjectID: [Data]]


/* Convenience getters. */
public extension LDAPRecord {
	
	/* Recommended way to access a record’s value.
	 * The descr OID is tried first, then the numericoid one. */
	func valueFor(oidPair: (LDAPObjectID.Descr, LDAPObjectID.Numericoid), expectedObjectClassName: String?) -> [Data]? {
		/* Check the given record has the proper class if required. */
		if let expectedObjectClassName {
			guard allObjectClasses?.contains(expectedObjectClassName) ?? false else {
				return nil
			}
		}
		return self[.descr(oidPair.0)] ?? self[.numericoid(oidPair.1)]
	}
	
	func valueFor(oid: LDAPObjectID, expectedObjectClassName: String?) -> [Data]? {
		/* Check the given record has the proper class if required. */
		if let expectedObjectClassName {
			guard allObjectClasses?.contains(expectedObjectClassName) ?? false else {
				return nil
			}
		}
		return self[oid]
	}
	
}


/* Convenience setters. */
public extension LDAPRecord {
	
	@discardableResult
	mutating func setValueIfNeeded(_ value: [Data], for oid: LDAPObjectID, numericoid: LDAPObjectID.Numericoid? = nil, expectedObjectClassName: String?) -> Bool {
		/* The only case where the setValue method throws is when the record does not have the correct class and allowAddingClass is false. */
		return try! setValueIfNeeded(value, for: oid, numericoid: numericoid, expectedObjectClassName: expectedObjectClassName, allowAddingClass: true)
	}
	
	/**
	 Set the given attribute value on the record.
	 
	 If `expectedObjectClassName`, the record will be checked of being a member of the given class.
	 If it is not and `allowAddingClass` is `true`, the class will be added, otherwise the set fails (throws).
	 
	 This function will remove the numericoid value from the record if any, then set the descr OID one. */
	@discardableResult
	mutating func setValueIfNeeded(_ value: [Data], for oid: LDAPObjectID, numericoid: LDAPObjectID.Numericoid? = nil, expectedObjectClassName: String?, allowAddingClass: Bool) throws -> Bool {
		/* Check the given record has the proper class if required. */
		var changedValue = false
		if let expectedObjectClassName {
			if !(allObjectClasses?.contains(expectedObjectClassName) ?? false) {
				/* The object does not have the expected class. */
				guard allowAddingClass else {
					throw Err.invalidLDAPRecordClass
				}
				
				changedValue = setValueIfNeeded(
					((objectClasses ?? []) + [expectedObjectClassName]).map{ Data($0.utf8) },
					for: .descr(LDAPTopClass.ObjectClass.descr),
					numericoid: LDAPTopClass.ObjectClass.numericoid,
					expectedObjectClassName: nil
				)
			}
		}
		
		if let numericoid {
			changedValue = (removeValue(forKey: .numericoid(numericoid)) != nil)
		}
		if self[oid] != value {
			changedValue = true
			self[oid] = value
		}
		return changedValue
	}
	
}


public extension LDAPRecord {
	
	var objectClasses: [String]? {
		return try? LDAPTopClass.ObjectClass.value(in: self, checkClass: false)
	}
	
	var allObjectClasses: Set<String>? {
		guard let classes = objectClasses else {
			return nil
		}
		
		/* Now let’s check for known classes and include the parent classes. */
		return Set(classes.flatMap{ className in
			guard let knownClass = knownClasses[className] else {
				return [className]
			}
			return [className] + knownClass.allParents.map{ $0.name }
		})
	}
	
}
