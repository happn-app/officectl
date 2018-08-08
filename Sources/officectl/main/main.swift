/*
 * main.swift
 * officectl
 *
 * Created by François Lamboley on 6/26/18.
 */

import Foundation

import Vapor



do    {try app().run()}
catch {print("Error creating the App!!"/* to stderr */); exit(255)}
