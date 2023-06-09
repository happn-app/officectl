/*
 * Queue.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/10.
 */

import Foundation

import TaskQueue



actor Queue : HasTaskQueue {
	
	var _taskQueue = TaskQueue()
	
	init() {
	}
	
}
