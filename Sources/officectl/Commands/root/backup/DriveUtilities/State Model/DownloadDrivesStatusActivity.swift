/*
 * DownloadDrivesStatusActivity.swift
 * officectl
 *
 * Created by François Lamboley on 11/02/2020.
 */

import Foundation

import OfficeKit
import Vapor



actor DownloadDrivesStatusActivity : ActivityIndicatorType {
	
	struct DownloadDriveStatus {
		
		var foundAllFiles: Bool = false
		var nFilesToProcess: Int = 0
		var nBytesToProcess: Int = 0
		
		var nFilesIgnored: Int = 0 /* Files that are not taking any quota in the drive. */
		var nBytesIgnored: Int = 0 /* Files that are not taking any quota in the drive. */
		
		var nFilesProcessed: Int = 0
		var nBytesProcessed: Int = 0
		
		var nFailures: Int = 0 /* Should always lower than or equal to the number of files processed. */
		
		var archiving: Bool = false
		var finished: Bool = false
		
	}
	
	var loadingBarWidth: Int = 27
	
	func initStatuses(users: [GoogleUser]) {
		var res = [GoogleUser: DownloadDriveStatus](minimumCapacity: users.count)
		for u in users {
			res[u] = DownloadDriveStatus()
		}
		statuses = res
	}
	
	subscript(_ user: GoogleUser) -> DownloadDriveStatus {
		get {
			statuses?[user] ?? DownloadDriveStatus()
		}
		set {
			if statuses == nil {statuses = [GoogleUser: DownloadDriveStatus]()}
			statuses![user] = newValue
		}
	}
	
	func updateStatus(for user: GoogleUser, _ updateBlock: @Sendable (inout DownloadDriveStatus) -> Void) {
		var status = self[user]
		updateBlock(&status)
		self[user] = status
	}
	
	nonisolated func outputActivityIndicator(to console: Console, state: ActivityIndicatorState) {
		Task{await _outputActivityIndicator(to: console, state: state)}
	}
	
	private func _outputActivityIndicator(to console: Console, state: ActivityIndicatorState) {
		guard let statuses = statuses else {
			console.info("Loading Users to Backup…")
			return
		}
		
		console.info("Drive Download Statuses by Users:")
		
		/* Note: We do not check the console size before doing the printing.
		 * If there is a very long username (or a very small console), the output will probably be weird… */
		
		let maxAccountWidth = self.maxAccountWidth ?? statuses.keys.map{ $0.primaryEmail.rawValue.count }.max() ?? 0
		
		var maxFoundFilesWidth = 0
		var maxTreatedFilesWidth = 0
		var maxIgnoredFilesWidth = 0
		var maxFailuresWidth = 0
		var maxFoundBytesWidth = 0
		var maxTreatedBytesWidth = 0
		var maxIgnoredBytesWidth = 0
		for s in statuses.values {
			maxFoundFilesWidth   = max(maxFoundFilesWidth,   numberWidth(s.nFilesToProcess) + (s.foundAllFiles ? 0 : 1))
			maxTreatedFilesWidth = max(maxTreatedFilesWidth, numberWidth(s.nFilesProcessed))
			maxIgnoredFilesWidth = max(maxIgnoredFilesWidth, numberWidth(s.nFilesIgnored))
			maxFailuresWidth     = max(maxFailuresWidth,     numberWidth(s.nFailures))
			maxFoundBytesWidth   = max(maxFoundBytesWidth,   bytesToHumanReadableString(s.nBytesToProcess).count + (s.foundAllFiles ? 0 : 1))
			maxTreatedBytesWidth = max(maxTreatedBytesWidth, bytesToHumanReadableString(s.nBytesProcessed).count)
			maxIgnoredBytesWidth = max(maxIgnoredBytesWidth, bytesToHumanReadableString(s.nBytesIgnored).count)
		}
		
		for user in statuses.keys.sorted(by: { $0.primaryEmail.rawValue < $1.primaryEmail.rawValue }) {
			let status = statuses[user]!
			
			var line = [ConsoleTextFragment]()
			let useremail = user.primaryEmail.rawValue
			
			line.append(ConsoleTextFragment(string: "   - ", style: .plain))
			line.append(ConsoleTextFragment(string: String(repeating: " ", count: maxAccountWidth - useremail.count) + useremail, style: .info))
			line.append(ConsoleTextFragment(string: " [", style: .plain))
			if status.foundAllFiles && (!status.archiving || status.finished) {
				/* Progress bar w/ actual progress shown. */
				let progressOK = status.nFilesToProcess == 0 ? 1.0 : Float(status.nFilesProcessed) / Float(status.nFilesToProcess)
				let progressError = status.nFilesToProcess == 0 ? 0.0 : Float(status.nFailures) / Float(status.nFilesToProcess)
				let leftOK = min(Int((Float(loadingBarWidth) * progressOK).rounded()), loadingBarWidth)
				let leftError = min(Int((Float(loadingBarWidth) * progressError).rounded()), loadingBarWidth - leftOK)
				let left = min(leftOK + leftError, loadingBarWidth)
				line.append(ConsoleTextFragment(string: String(repeating: status.finished ? "~" : "=", count: leftOK),                 style: .plain))
				line.append(ConsoleTextFragment(string: String(repeating: " ", count: loadingBarWidth - left), style: .plain))
				line.append(ConsoleTextFragment(string: String(repeating: status.finished ? "~" : "=", count: leftError),              style: .error))
			} else {
				/* Indeterminate progress bar as we don’t know the progress. */
				let bulletPosition: Int
				switch state {
					case .active(tick: let actualT):
						let t = UInt((Float(actualT)/2).rounded(.down)) /* Slow down the back-and forth motion */
						let period = loadingBarWidth - 1
						let offset  = Int(t % UInt(period))
						let reverse = Int(t % UInt(period*2)) >= period
						bulletPosition = !reverse ? offset : loadingBarWidth - offset - 1
						
					default:
						bulletPosition = 0
				}
				line.append(ConsoleTextFragment(string: String(repeating: status.archiving ? "~" : " ", count: bulletPosition), style: .plain))
				line.append(ConsoleTextFragment(string: status.archiving ? "=" : "•", style: .plain))
				line.append(ConsoleTextFragment(string: String(repeating: status.archiving ? "~" : " ", count: loadingBarWidth - bulletPosition - 1), style: .plain))
			}
			/* Showing the number of downloaded files */
			line.append(ConsoleTextFragment(string: "] Downloaded ", style: .plain))
			line.append(ConsoleTextFragment(string: String(repeating: " ", count: maxTreatedFilesWidth - numberWidth(status.nFilesProcessed)), style: .plain))
			line.append(ConsoleTextFragment(string: String(status.nFilesProcessed), style: .plain))
			line.append(ConsoleTextFragment(string: "/", style: .plain))
			line.append(ConsoleTextFragment(string: String(status.nFilesToProcess), style: status.foundAllFiles ? .plain : .info))
			if !status.foundAllFiles {
				line.append(ConsoleTextFragment(string: "+", style: .info))
			}
			line.append(ConsoleTextFragment(string: String(repeating: " ", count: maxFoundFilesWidth - (numberWidth(status.nFilesToProcess) + (status.foundAllFiles ? 0 : 1))), style: .plain))
			line.append(ConsoleTextFragment(string: String(repeating: " ", count: maxIgnoredFilesWidth - numberWidth(status.nFilesIgnored)), style: .plain))
			line.append(ConsoleTextFragment(string: " (", style: .plain))
			line.append(ConsoleTextFragment(string: String(status.nFilesIgnored) + " ignored", style: .warning))
			line.append(ConsoleTextFragment(string: "), ", style: .plain))
			/* Showing the number of downloaded bytes */
			line.append(ConsoleTextFragment(string: String(repeating: " ", count: maxTreatedBytesWidth - bytesToHumanReadableString(status.nBytesProcessed).count), style: .plain))
			line.append(ConsoleTextFragment(string: bytesToHumanReadableString(status.nBytesProcessed), style: .plain))
			line.append(ConsoleTextFragment(string: "/", style: .plain))
			line.append(ConsoleTextFragment(string: bytesToHumanReadableString(status.nBytesToProcess), style: status.foundAllFiles ? .plain : .info))
			if !status.foundAllFiles {
				line.append(ConsoleTextFragment(string: "+", style: .info))
			}
			line.append(ConsoleTextFragment(string: String(repeating: " ", count: maxFoundBytesWidth - (bytesToHumanReadableString(status.nBytesToProcess).count + (status.foundAllFiles ? 0 : 1))), style: .plain))
			line.append(ConsoleTextFragment(string: String(repeating: " ", count: maxIgnoredBytesWidth - bytesToHumanReadableString(status.nBytesIgnored).count), style: .plain))
			line.append(ConsoleTextFragment(string: " (", style: .plain))
			line.append(ConsoleTextFragment(string: bytesToHumanReadableString(status.nBytesIgnored) + " ignored", style: .warning))
			line.append(ConsoleTextFragment(string: "); failed ", style: .plain))
			line.append(ConsoleTextFragment(string: String(repeating: " ", count: maxFailuresWidth - numberWidth(status.nFailures)), style: .plain))
			line.append(ConsoleTextFragment(string: String(status.nFailures), style: status.nFailures == 0 ? .success : .error))
			
			console.output(ConsoleText(fragments: line))
		}
	}
	
	private var maxAccountWidth: Int?
	private var statuses: [GoogleUser: DownloadDriveStatus]?
	
	private func bytesToHumanReadableString(_ bytes: Int) -> String {
		func nextStep(_ currentValue: Double, currentSuffixes: [String]) -> String {
			let r = Int(currentValue.rounded())
			if r < 1024 || currentSuffixes.count == 1 {
				return String(r) + currentSuffixes.first!
			}
			return nextStep(currentValue/1024, currentSuffixes: Array(currentSuffixes.dropFirst()))
		}
		return nextStep(Double(bytes), currentSuffixes: ["B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"])
	}
	
	private func numberWidth(_ n: Int) -> Int {
		switch n {
			case 0: return 1
			case ...(-1): return numberWidth(n) + 1
			case 1...:    return Int(log10(Float(n))) + 1
			default: return 1 /* Should not be possible… */
		}
	}
	
}
