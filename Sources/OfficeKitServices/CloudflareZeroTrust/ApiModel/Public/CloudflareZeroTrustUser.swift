/*
 * CloudflareZeroTrustUser.swift
 * CloudflareZeroTrustOffice
 *
 * Created by François Lamboley on 2023/07/26.
 */

import Foundation

import Email

import OfficeKit



/* Doc <https://developers.cloudflare.com/api/operations/zero-trust-users-get-users> says none of the properties are required…
 * I have nonetheless put a few properties as non-optional, because (I can’t see how those properties could be nil).
 *
 * However, the email property is, sadly, optional.
 * I have not tested the theory, but I guess if we activate some login methods (e.g. SAML w/ no email configured),
 *  we could indeed get users with a nil email. */
public struct CloudflareZeroTrustUser : Sendable, Hashable, Codable {
	
	/** The ID of the user. */
	public var id: String?
	/** The unique API identifier for the user. */
	public var uid: String?
	/** The unique API identifier for the Zero Trust seat. */
	public var seatUID: String
	
	/** The email of the user. */
	public var email: Email?
	/** The name of the user. */
	@EmptyIsNil
	public var name: String?
	
	public var createdAt: Date?
	public var updatedAt: Date?
	/** The time at which the user last successfully logged in. */
	public var lastSuccessfulLogin: Date?
	
	/** `true` if the user has authenticated with Cloudflare Access. */
	public var accessSeat: Bool
	/** `true` if the user has logged into the WARP client. */
	public var gatewaySeat: Bool
	
	/** The number of active devices registered to the user. */
	public var activeDeviceCount: Int?
	
	enum CodingKeys : String, CodingKey {
		
		case id, uid, seatUID = "seat_uid"
		case email, name
		case createdAt = "created_at", updatedAt = "updated_at", lastSuccessfulLogin = "last_successful_login"
		case accessSeat = "access_seat", gatewaySeat = "gateway_seat"
		case activeDeviceCount = "active_device_count"
		
	}
	
}
