/*
 * UserConfirmation.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/24.
 */

import Foundation

import StreamReader



enum UserConfirmation {
	
	static func confirmYesOrNo<Output : TextOutputStream>(
		prompt: String = "Is this ok (y/n)? ",
		invalidAnswerNotice: String = "Only [y]es or [n]o> ",
		inputFileHandle: FileHandle,
		outputStream: inout Output
	) throws -> Bool {
		let reader = FileHandleReader(stream: inputFileHandle, bufferSize: 64, bufferSizeIncrement: 32, underlyingStreamReadSizeLimit: 1)
		print(prompt, terminator: "", to: &outputStream)
		while let l = try reader.readLine()?.line {
			switch String(data: l, encoding: .utf8) {
				case "y"?, "yes"?: return true
				case "n"?, "no"?:  return false
				default:
					print(invalidAnswerNotice, terminator: "", to: &outputStream)
			}
		}
		return false
	}
	
}
