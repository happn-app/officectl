/*
 * DispatchQueue+Sendable.swift
 * officectl
 *
 * Created by François Lamboley on 2022/09/26.
 */

import Foundation



/* Using same rationale as OperationQueue: <https://forums.swift.org/t/sendable-in-foundation/59577> */
extension DispatchQueue : @unchecked Sendable {}
