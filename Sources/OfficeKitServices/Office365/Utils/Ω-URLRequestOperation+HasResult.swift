/*
 * URLRequestOperation+HasResult.swift
 * Office365Office
 *
 * Created by François Lamboley on 2023/01/25.
 */

import Foundation

import HasResult
import OperationAwaiting
import URLRequestOperation



extension URLRequestDataOperation : HasResult, SendableOperation {}
extension URLRequestDownloadOperation : HasResult, SendableOperation {}
