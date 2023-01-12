/*
 * URLRequestOperation+HasResult.swift
 * OfficeKitOffice
 *
 * Created by François Lamboley on 2023/01/09.
 */

import Foundation

import HasResult
import OperationAwaiting
import URLRequestOperation



extension URLRequestDataOperation : HasResult, SendableOperation {}
extension URLRequestDownloadOperation : HasResult, SendableOperation {}
