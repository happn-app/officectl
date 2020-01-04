/*
 * OfficeKitService.swift
 * OfficeKit
 *
 * Created by François Lamboley on 24/09/2019.
 */

import Foundation



/* Notes regarding the dependency injection:
 *    - because we are creating a protocol here for an unknown generic service
 *      and therefore cannot truly know which dependencies will be needed by the
 *      actual services which will be created (we can guess an event loop will
 *      always be needed, but we don’t know much more), we only ask for one
 *      dependency: a `Services`, object which allows the retrieval of other
 *      dependencies;
 *    - we do not inject dependency at init time, but instead give all the
 *      dependencies at each call of the methods of the service (see any
 *      `OfficeKit` service, each method takes a `Services` argument). This
 *      allows for instance using a different event loop for each request, etc.
 *
 * It is interesting to note this approach differs from Vapor 4’s, but is close
 * to Vapor 3’s.
 * Vapor 3 used to have a `Container` (our `Services` object is heavily inspired
 * by this actually) to do the dependency injection. Now, as far as I understand
 * it, Vapor 4 expects the services to have its dependencies setup at init time,
 * and potentially have a derived service created if needed with
 * `service.for(_ r: Request)` for dependencies that are dependant on the
 * upstream request (event loop, etc.)
 * We decided against this solution because:
 *    - I like having an explicit argument being passed to my method
 *      representing the dependencies I need,
 *    - unlike Vapor which has services with explicit dependencies, our services
 *      have dependencies we cannot know at compile time so we only get, in
 *      practice, the `Services` dependency. This guarantees us we’ll only ever
 *      have one argument to pass to our methods, even if new dependencies are
 *      needed,
 *    - the derived service approach forces the services to be stateless (though
 *      this is not necessarily a bad thing in all honesty). */

public protocol OfficeKitService : class, Hashable, OfficeKitServiceInit {
	
	/** The id of the linked provider, e.g. "internal_openldap". External
	provider ids (not builtin to OfficeKit) must not have the “internal_” prefix. */
	static var providerId: String {get}
	
	associatedtype ConfigType : OfficeKitServiceConfig
	
	var config: ConfigType {get}
	var globalConfig: GlobalConfig {get}
	
	init(config c: ConfigType, globalConfig gc: GlobalConfig)
	
}


extension OfficeKitService {
	
	public static func ==(_ lhs: Self, _ rhs: Self) -> Bool {
		return lhs.config.serviceId == rhs.config.serviceId
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(config.serviceId)
	}
	
}



/* **********************
   MARK: - Erasure Things
   ********************** */

public protocol OfficeKitServiceInit {
	
	static var configType: OfficeKitServiceConfigInit.Type {get}
	/* The service provider does not have enough info to do the service
	 * de-duplication. We have to do it in the implementation of this method, and
	 * of all the other *Init protocols. Hence the cachedServices argument. */
	static func erasedService(anyConfig c: Any, globalConfig gc: GlobalConfig, cachedServices: [AnyOfficeKitService]?) -> AnyOfficeKitService?
	
}

/* Implementation of OfficeKitServiceInit */
public extension OfficeKitService {
	
	static var configType: OfficeKitServiceConfigInit.Type {
		return ConfigType.self
	}
	
	static func erasedService(anyConfig c: Any, globalConfig gc: GlobalConfig, cachedServices: [AnyOfficeKitService]?) -> AnyOfficeKitService? {
		guard let c: ConfigType = c as? ConfigType ?? (c as? AnyOfficeKitServiceConfig)?.unbox() else {return nil}
		
		if let alreadyInstantiated = cachedServices?.compactMap({ $0.unbox() as Self? }).first(where: { $0.config.serviceId == c.serviceId }) {
			return alreadyInstantiated.erase()
		}
		
		return self.init(config: c, globalConfig: gc).erase()
	}
	
}
