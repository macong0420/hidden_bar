//
//  MouseCursor.swift
//  HiddenBar
//
//  Adapted from Ice (https://github.com/jordanbaird/Ice)
//  Copyright (c) Jordan Baird — Licensed under GNU GPL v3.0 or later.
//

import CoreGraphics

/// A namespace for mouse cursor operations.
enum MouseCursor {
    static var locationAppKit: CGPoint? {
        CGEvent(source: nil)?.unflippedLocation
    }

    static var locationCoreGraphics: CGPoint? {
        CGEvent(source: nil)?.location
    }

    static func hide() {
        let result = CGDisplayHideCursor(CGMainDisplayID())
        if result != .success {
            Logger.mouseCursor.error("CGDisplayHideCursor failed with error \(result.logString)")
        }
    }

    static func show() {
        let result = CGDisplayShowCursor(CGMainDisplayID())
        if result != .success {
            Logger.mouseCursor.error("CGDisplayShowCursor failed with error \(result.logString)")
        }
    }

    static func warp(to point: CGPoint) {
        let result = CGWarpMouseCursorPosition(point)
        if result != .success {
            Logger.mouseCursor.error("CGWarpMouseCursorPosition failed with error \(result.logString)")
        }
    }
}

private extension Logger {
    static let mouseCursor = Logger(category: "MouseCursor")
}
