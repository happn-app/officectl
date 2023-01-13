/*
 * Environment.swift
 * officectl
 *
 * Created by François Lamboley on 2023/01/12.
 */

import Foundation

import ArgumentParser



enum Environment : CaseIterable, ExpressibleByArgument {

	case development
	case production

	init?(argument: String) {
		switch argument {
			case let str where str.starts(with: "dev"):  self = .development
			case let str where str.starts(with: "prod"): self = .production
			default: return nil
		}
	}

}
