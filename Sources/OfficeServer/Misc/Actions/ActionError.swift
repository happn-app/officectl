/*
 * ActionError.swift
 * OfficeServer
 *
 * Created by François Lamboley on 2023/01/19.
 */

import Foundation



public enum ActionError : Error {
	
	case actionIsNotFinished
	case actionIsAlreadyRunning
	
}
