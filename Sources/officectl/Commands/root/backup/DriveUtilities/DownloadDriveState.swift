/*
 * DownloadDriveState.swift
 * officectl
 *
 * Created by François Lamboley on 11/02/2020.
 */

import Foundation

import NIO
import OfficeKit



class DownloadDriveState {
	
	let connector: GoogleJWTConnector
	let eventLoop: EventLoop
	let status: DownloadDrivesStatusActivity
	let logFile: LogFile
	
	let userAndDest: GoogleUserAndDest
	let driveDestinationBaseURL: URL
	let allFilesDestinationBaseURL: URL
	
	init(connector c: GoogleJWTConnector, eventLoop el: EventLoop, status s: DownloadDrivesStatusActivity, logFile lf: LogFile, userAndDest uad: GoogleUserAndDest, driveDestinationBaseURL ddbu: URL, allFilesDestinationBaseURL afdbu: URL) {
		connector = c
		eventLoop = el
		status = s
		logFile = lf
		userAndDest = uad
		driveDestinationBaseURL = ddbu
		allFilesDestinationBaseURL = afdbu
	}
	
}
