/*
 * Utils.swift
 * officectl
 *
 * Created by François Lamboley on 2019/7/13.
 */

import Foundation



func generateRandomPassword(length: Int = 13) -> String {
	let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	return String((0..<length).map{ _ in chars.randomElement()! })
}
