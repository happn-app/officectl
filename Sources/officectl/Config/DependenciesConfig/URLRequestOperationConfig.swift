/*
 * URLRequestOperationConfig.swift
 * officectl
 *
 * Created by François Lamboley on 20/02/2019.
 */

import URLRequestOperation



func configureURLRequestOperation(_ config: OfficectlConfig) {
	#if canImport(os)
		di.log = config.verbose ? .default : nil
	#else
		di.log = config.verbose ? () : nil
	#endif
}
