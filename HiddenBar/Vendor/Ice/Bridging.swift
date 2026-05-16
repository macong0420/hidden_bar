//
//  Bridging.swift
//  HiddenBar
//
//  Adapted from Ice (https://github.com/jordanbaird/Ice)
//  Copyright (c) Jordan Baird — Licensed under GNU GPL v3.0 or later.
//

import Cocoa

/// A namespace for bridged functionality.
enum Bridging { }

// MARK: - CGSConnection

extension Bridging {
    static func setConnectionProperty(_ value: Any?, forKey key: String) {
        let result = CGSSetConnectionProperty(
            CGSMainConnectionID(),
            CGSMainConnectionID(),
            key as CFString,
            value as CFTypeRef
        )
        if result != .success {
            Logger.bridging.error("CGSSetConnectionProperty failed with error \(result.logString)")
        }
    }

    static func getConnectionProperty(forKey key: String) -> Any? {
        var value: Unmanaged<CFTypeRef>?
        let result = CGSCopyConnectionProperty(
            CGSMainConnectionID(),
            CGSMainConnectionID(),
            key as CFString,
            &value
        )
        if result != .success {
            Logger.bridging.error("CGSCopyConnectionProperty failed with error \(result.logString)")
        }
        return value?.takeRetainedValue()
    }
}

// MARK: - CGSWindow

extension Bridging {
    static func getWindowFrame(for windowID: CGWindowID) -> CGRect? {
        var rect = CGRect.zero
        let result = CGSGetScreenRectForWindow(CGSMainConnectionID(), windowID, &rect)
        guard result == .success else {
            Logger.bridging.error("CGSGetScreenRectForWindow failed with error \(result.logString)")
            return nil
        }
        return rect
    }
}

// MARK: Private Window List Helpers

extension Bridging {
    private static func getWindowCount() -> Int {
        var count: Int32 = 0
        let result = CGSGetWindowCount(CGSMainConnectionID(), 0, &count)
        if result != .success {
            Logger.bridging.error("CGSGetWindowCount failed with error \(result.logString)")
        }
        return Int(count)
    }

    private static func getOnScreenWindowCount() -> Int {
        var count: Int32 = 0
        let result = CGSGetOnScreenWindowCount(CGSMainConnectionID(), 0, &count)
        if result != .success {
            Logger.bridging.error("CGSGetOnScreenWindowCount failed with error \(result.logString)")
        }
        return Int(count)
    }

    private static func getWindowList() -> [CGWindowID] {
        let windowCount = getWindowCount()
        var list = [CGWindowID](repeating: 0, count: windowCount)
        var realCount: Int32 = 0
        let result = CGSGetWindowList(
            CGSMainConnectionID(),
            0,
            Int32(windowCount),
            &list,
            &realCount
        )
        guard result == .success else {
            Logger.bridging.error("CGSGetWindowList failed with error \(result.logString)")
            return []
        }
        return [CGWindowID](list[..<Int(realCount)])
    }

    private static func getOnScreenWindowList() -> [CGWindowID] {
        let windowCount = getOnScreenWindowCount()
        var list = [CGWindowID](repeating: 0, count: windowCount)
        var realCount: Int32 = 0
        let result = CGSGetOnScreenWindowList(
            CGSMainConnectionID(),
            0,
            Int32(windowCount),
            &list,
            &realCount
        )
        guard result == .success else {
            Logger.bridging.error("CGSGetOnScreenWindowList failed with error \(result.logString)")
            return []
        }
        return [CGWindowID](list[..<Int(realCount)])
    }

    private static func getMenuBarWindowList() -> [CGWindowID] {
        let windowCount = getWindowCount()
        var list = [CGWindowID](repeating: 0, count: windowCount)
        var realCount: Int32 = 0
        let result = CGSGetProcessMenuBarWindowList(
            CGSMainConnectionID(),
            0,
            Int32(windowCount),
            &list,
            &realCount
        )
        guard result == .success else {
            Logger.bridging.error("CGSGetProcessMenuBarWindowList failed with error \(result.logString)")
            return []
        }
        return [CGWindowID](list[..<Int(realCount)])
    }

    private static func getOnScreenMenuBarWindowList() -> [CGWindowID] {
        let onScreenList = Set(getOnScreenWindowList())
        return getMenuBarWindowList().filter(onScreenList.contains)
    }
}

// MARK: Public Window List API

extension Bridging {
    struct WindowListOption: OptionSet {
        let rawValue: Int

        static let onScreen = WindowListOption(rawValue: 1 << 0)
        static let menuBarItems = WindowListOption(rawValue: 1 << 1)
        static let activeSpace = WindowListOption(rawValue: 1 << 2)
    }

    static var windowCount: Int {
        getWindowCount()
    }

    static var onScreenWindowCount: Int {
        getOnScreenWindowCount()
    }

    static func getWindowList(option: WindowListOption = []) -> [CGWindowID] {
        let list = if option.contains(.menuBarItems) {
            if option.contains(.onScreen) {
                getOnScreenMenuBarWindowList()
            } else {
                getMenuBarWindowList()
            }
        } else if option.contains(.onScreen) {
            getOnScreenWindowList()
        } else {
            getWindowList()
        }
        return if option.contains(.activeSpace) {
            list.filter(isWindowOnActiveSpace)
        } else {
            list
        }
    }
}

// MARK: - CGSSpace

extension Bridging {
    enum SpaceListOption {
        case allSpaces, visibleSpaces
    }

    static var activeSpaceID: CGSSpaceID {
        CGSGetActiveSpace(CGSMainConnectionID())
    }

    static func getSpaceList(for windowID: CGWindowID, option: SpaceListOption) -> [CGSSpaceID] {
        let mask: CGSSpaceMask = switch option {
        case .allSpaces: .allSpaces
        case .visibleSpaces: .allVisibleSpaces
        }
        guard let spaces = CGSCopySpacesForWindows(CGSMainConnectionID(), mask, [windowID] as CFArray) else {
            Logger.bridging.error("CGSCopySpacesForWindows failed")
            return []
        }
        guard let spaceIDs = spaces.takeRetainedValue() as? [CGSSpaceID] else {
            Logger.bridging.error("CGSCopySpacesForWindows returned array of unexpected type")
            return []
        }
        return spaceIDs
    }

    static func isWindowOnActiveSpace(_ windowID: CGWindowID) -> Bool {
        getSpaceList(for: windowID, option: .allSpaces).contains(activeSpaceID)
    }

    static func isSpaceFullscreen(_ spaceID: CGSSpaceID) -> Bool {
        let type = CGSSpaceGetType(CGSMainConnectionID(), spaceID)
        return type == .fullscreen
    }
}

// MARK: - Process Responsivity

extension Bridging {
    enum Responsivity {
        case responsive, unresponsive, unknown
    }

    static func responsivity(for pid: pid_t) -> Responsivity {
        var psn = ProcessSerialNumber()
        let result = GetProcessForPID(pid, &psn)
        guard result == noErr else {
            Logger.bridging.error("GetProcessForPID failed with error \(result)")
            return .unknown
        }
        if CGSEventIsAppUnresponsive(CGSMainConnectionID(), &psn) {
            return .unresponsive
        }
        return .responsive
    }
}

private extension Logger {
    static let bridging = Logger(category: "Bridging")
}
