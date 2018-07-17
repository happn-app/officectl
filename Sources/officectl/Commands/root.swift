/*
 * root.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import Guaka
import NIO

import OfficeKit



func root(flags f: Flags, arguments args: [String], asyncConfig: AsyncConfig) -> EventLoopFuture<Void> {
	return asyncConfig.eventLoop.newFailedFuture(error: NSError(domain: "com.happn.officectl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Please choose a command verb"]))
}
