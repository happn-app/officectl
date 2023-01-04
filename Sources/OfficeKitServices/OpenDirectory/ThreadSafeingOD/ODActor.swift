/*
 * OpenDirectoryActor.swift
 * OpenDirectoryOffice
 *
 * Created by François Lamboley on 2023/01/04.
 */

import Foundation



@globalActor
public enum ODActor {
	public actor Actor {}
	public static let shared: Actor = .init()
}
