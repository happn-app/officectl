/*
 * SynologyApiError.swift
 * SynologyOffice
 *
 * Created by François Lamboley on 2023/06/06.
 */

import Foundation



public struct SynologyApiError : Decodable, Sendable {
	
	public var code: Int
	/* TODO: “errors” field.
	 * See <https://global.download.synology.com/download/Document/Software/DeveloperGuide/Os/DSM/All/enu/DSM_Login_Web_API_Guide_enu.pdf>. */
	
	public enum CodingKeys: CodingKey {
		case code
	}
	
}
