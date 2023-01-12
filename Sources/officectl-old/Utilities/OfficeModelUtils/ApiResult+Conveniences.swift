/*
 * ApiResult+Conveniences.swift
 * officectl
 *
 * Created by François Lamboley on 2022/01/13.
 */

import Foundation

import Vapor

import OfficeModel



extension ApiResult {
	
	init<Failure : Error>(result: Result<Success, Failure>, environment: Environment) {
		switch result {
			case .success(let s): self = .success(s)
			case .failure(let f): self = .failure(ApiError(error: f, environment: environment))
		}
	}
	
}
