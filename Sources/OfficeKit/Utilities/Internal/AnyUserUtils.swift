/*
 * AnyUserUtils.swift
 * OfficeKit
 *
 * Created by François Lamboley on 16/09/2019.
 */

import Foundation



internal func fullNameFrom(firstName: String?, lastName: String?) -> String? {
	switch (firstName, lastName) {
		case (let fn?, let ln?): return fn + " " + ln
		case (let fn?, nil):     return fn
		case (nil, let sn?):     return sn
		case (nil, nil):         return nil
	}
}
