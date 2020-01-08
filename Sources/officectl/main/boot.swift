/*
 * boot.swift
 * officectl
 *
 * Created by François Lamboley on 06/08/2018.
 */

import Foundation

import OfficeKit
import Vapor



/** Called after the application has initialized. */
public func boot(_ app: Application) throws {
	OfficeKitConfig.logger = app.logger
}
