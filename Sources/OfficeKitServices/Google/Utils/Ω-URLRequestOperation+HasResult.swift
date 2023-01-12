/*
 * URLRequestOperation+HasResult.swift
 * GoogleOffice
 *
 * Created by François Lamboley on 2022/11/17.
 */

import Foundation

import HasResult
import OperationAwaiting
import URLRequestOperation



extension URLRequestDataOperation : HasResult, SendableOperation {}
extension URLRequestDownloadOperation : HasResult, SendableOperation {}
