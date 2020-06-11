/*
 * RetryingOperationConfig.swift
 * officectl
 *
 * Created by François Lamboley on 29/06/2019.
 */

import RetryingOperation



func configureRetryingOperation(_ config: OfficectlConfig) {
	#if canImport(os)
		di.log = config.verbose ? .default : nil
	#else
		di.log = config.verbose ? () : nil
	#endif
}
