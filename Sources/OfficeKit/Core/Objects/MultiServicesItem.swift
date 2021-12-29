/*
 * MultiServicesItem.swift
 * OfficeKit
 *
 * Created by François Lamboley on 2019/08/19.
 */

import Foundation



public struct MultiServicesItem<ItemType> {
	
	public var errorsAndItemsByService: [AnyUserDirectoryService: Result<ItemType, Error>]
	
	public var itemsByService:  [AnyUserDirectoryService: ItemType] {return errorsAndItemsByService.compactMapValues{ $0.successValue }}
	public var errorsByService: [AnyUserDirectoryService: Error]    {return errorsAndItemsByService.compactMapValues{ $0.failureValue }}
	
	public var errorsAndItemsByServiceId: [String: Result<ItemType, Error>] {
		return errorsAndItemsByService.mapKeys{ $0.config.serviceId }
	}
	
	public var itemsByServiceId:  [String: ItemType] {return itemsByService.mapKeys{  $0.config.serviceId }}
	public var errorsByServiceId: [String: Error]    {return errorsByService.mapKeys{ $0.config.serviceId }}
	
	public var services: Set<AnyUserDirectoryService> {
		return Set(errorsAndItemsByService.keys)
	}
	
	/**
	 Creates the MultiServicesUser with the given pairs and errors.
	 If, for a given service there is a user and some errors, the user will be chosen. */
	init(itemsByService pbsi: [AnyUserDirectoryService: ItemType] = [:], errorsByService ebsi: [AnyUserDirectoryService: Error] = [:]) {
		self.init(errorsAndItemsByService: pbsi.mapValues{ .success($0) }.merging(ebsi.mapValues{ .failure($0) }, uniquingKeysWith: { old, _ in old }))
	}
	
	init(errorsAndItemsByService eapbsi: [AnyUserDirectoryService: Result<ItemType, Error>]) {
		errorsAndItemsByService = eapbsi
	}
	
	public subscript<ServiceType : UserDirectoryService>(service: ServiceType) -> ItemType? {
		return itemsByService[service.erase()]
	}
	
	public func map<NewItemType>(to type: NewItemType.Type = NewItemType.self, _ callback: (Result<ItemType, Error>) -> Result<NewItemType, Error>) -> MultiServicesItem<NewItemType> {
		return MultiServicesItem<NewItemType>(errorsAndItemsByService: errorsAndItemsByService.mapValues{ callback($0) })
	}
	
	public func mapItems<NewItemType>(to type: NewItemType.Type = NewItemType.self, _ callback: (ItemType) throws -> NewItemType) -> MultiServicesItem<NewItemType> {
		return MultiServicesItem<NewItemType>(errorsAndItemsByService: errorsAndItemsByService.mapValues{ $0.flatMap{ item in Result{ try callback(item) } } })
	}
	
}
