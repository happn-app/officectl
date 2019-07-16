/*
 * URLRequestOperationConfig.swift
 * officectl
 *
 * Created by François Lamboley on 20/02/2019.
 */

import URLRequestOperation



func configureURLRequestOperation(_ verbose: Bool) {
	#if canImport(os)
		di.log = verbose ? .default : nil
	#else
		di.log = verbose ? () : nil
	#endif
}
