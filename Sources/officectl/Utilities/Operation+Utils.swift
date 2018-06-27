/*
 * Operation+Utils.swift
 * officectl
 *
 * Created by François Lamboley on 26/06/2018.
 */

import Foundation



extension Operation {
	
	var selfAndRecursiveDependencies: [Operation] {
		return [self] + dependencies.flatMap{ $0.selfAndRecursiveDependencies }
	}
	
}
