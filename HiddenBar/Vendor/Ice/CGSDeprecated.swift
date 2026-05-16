//
//  CGSDeprecated.swift
//  HiddenBar
//
//  Adapted from Ice (https://github.com/jordanbaird/Ice) — Bridging/Shims/Deprecated.swift
//  Copyright (c) Jordan Baird — Licensed under GNU GPL v3.0 or later.
//

import ApplicationServices

@_silgen_name("GetProcessForPID")
func GetProcessForPID(
    _ pid: pid_t,
    _ psn: inout ProcessSerialNumber
) -> OSStatus
