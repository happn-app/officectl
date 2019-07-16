/*
 * RetryingOperationConfig.swift
 * officectl
 *
 * Created by François Lamboley on 29/06/2019.
 */

import RetryingOperation



func configureRetryingOperation(_ verbose: Bool) {
	#if canImport(os)
		di.log = verbose ? .default : nil
	#else
		di.log = verbose ? () : nil
	#endif
}
