//
//  MenuBarItemMover.swift
//  HiddenBar
//
//  Adapted from Ice (https://github.com/jordanbaird/Ice) — MenuBar/MenuBarItems/MenuBarItemManager.swift
//  Copyright (c) Jordan Baird — Licensed under GNU GPL v3.0 or later.
//
//  Trimmed to retain only the move-item path used by HiddenBar's allowlist
//  feature. Click forwarding, always-hidden section logic, temp-show items
//  and the event manager glue layer were intentionally omitted.
//

import AppKit
import CoreGraphics

@MainActor
final class MenuBarItemMover {
    struct EventError: Error, CustomStringConvertible, LocalizedError {
        enum Code: Int, CustomStringConvertible {
            case couldNotComplete
            case eventCreationFailure
            case invalidEventSource
            case invalidCursorLocation
            case invalidItem
            case notMovable
            case eventOperationTimeout
            case frameCheckTimeout

            var description: String {
                switch self {
                case .couldNotComplete: "couldNotComplete"
                case .eventCreationFailure: "eventCreationFailure"
                case .invalidEventSource: "invalidEventSource"
                case .invalidCursorLocation: "invalidCursorLocation"
                case .invalidItem: "invalidItem"
                case .notMovable: "notMovable"
                case .eventOperationTimeout: "eventOperationTimeout"
                case .frameCheckTimeout: "frameCheckTimeout"
                }
            }
        }

        let code: Code
        let item: MenuBarItem

        var description: String { "MenuBarItemMover.EventError(\(code), item: \(item.logString))" }
        var errorDescription: String? { description }
    }

    enum MoveDestination {
        case leftOfItem(MenuBarItem)
        case rightOfItem(MenuBarItem)

        var logString: String {
            switch self {
            case .leftOfItem(let item): "left of \(item.logString)"
            case .rightOfItem(let item): "right of \(item.logString)"
            }
        }
    }

    private let maxAttempts: Int = 2

    func move(item: MenuBarItem, to destination: MoveDestination) async throws {
        if try itemHasCorrectPosition(item: item, for: destination) {
            return
        }

        do {
            try await waitForNoModifiersPressed(timeout: .seconds(1))
        } catch {
            throw EventError(code: .couldNotComplete, item: item)
        }

        guard let cursorLocation = MouseCursor.locationCoreGraphics else {
            throw EventError(code: .invalidCursorLocation, item: item)
        }
        guard let initialFrame = getCurrentFrame(for: item) else {
            throw EventError(code: .invalidItem, item: item)
        }
        _ = initialFrame

        MouseCursor.hide()
        defer {
            MouseCursor.warp(to: cursorLocation)
            MouseCursor.show()
        }

        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                try await moveItemWithoutRestoringMouseLocation(item, to: destination)
                if let newFrame = getCurrentFrame(for: item),
                   try itemHasCorrectPosition(item: item, for: destination, currentFrame: newFrame) {
                    Logger.itemMover.debug("Moved \(item.logString) to \(destination.logString) on attempt #\(attempt)")
                    return
                }
                lastError = EventError(code: .couldNotComplete, item: item)
            } catch {
                lastError = error
                Logger.itemMover.warning("Move attempt #\(attempt) for \(item.logString) failed: \(error.localizedDescription)")
            }
        }
        throw lastError ?? EventError(code: .couldNotComplete, item: item)
    }

    private func moveItemWithoutRestoringMouseLocation(
        _ item: MenuBarItem,
        to destination: MoveDestination
    ) async throws {
        guard item.isMovable else {
            throw EventError(code: .notMovable, item: item)
        }
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw EventError(code: .invalidEventSource, item: item)
        }

        let startPoint = CGPoint(x: 20_000, y: 20_000)
        let endPoint = try getEndPoint(for: destination)
        let fallbackPoint = try getFallbackPoint(for: item)
        let targetItem = getTargetItem(for: destination)

        guard
            let mouseDownEvent = CGEvent.menuBarItemEvent(
                type: .move(.leftMouseDown),
                location: startPoint,
                item: item,
                pid: item.ownerPID,
                source: source
            ),
            let mouseUpEvent = CGEvent.menuBarItemEvent(
                type: .move(.leftMouseUp),
                location: endPoint,
                item: targetItem,
                pid: item.ownerPID,
                source: source
            ),
            let fallbackEvent = CGEvent.menuBarItemEvent(
                type: .move(.leftMouseUp),
                location: fallbackPoint,
                item: item,
                pid: item.ownerPID,
                source: source
            )
        else {
            throw EventError(code: .eventCreationFailure, item: item)
        }

        try permitAllEvents(
            for: .combinedSessionState,
            during: [.eventSuppressionStateRemoteMouseDrag, .eventSuppressionStateSuppressionInterval],
            suppressionInterval: 0,
            item: item
        )

        do {
            try await scrombleEvent(
                mouseDownEvent,
                from: .pid(item.ownerPID),
                to: .sessionEventTap,
                waitingForFrameChangeOf: item
            )
            try await scrombleEvent(
                mouseUpEvent,
                from: .pid(item.ownerPID),
                to: .sessionEventTap,
                waitingForFrameChangeOf: item
            )
        } catch {
            Logger.itemMover.debug("Posting fallback event for moving \(item.logString)")
            try? await postEventAndWaitToReceive(fallbackEvent, to: .sessionEventTap, item: item)
            throw error
        }
    }

    private func waitForNoModifiersPressed(timeout: Duration) async throws {
        try await Task(timeout: timeout) {
            while !NSEvent.modifierFlags.isEmpty {
                try Task.checkCancellation()
                try await _Concurrency.Task.sleep(for: .milliseconds(20))
            }
        }.value
    }

    private func getCurrentFrame(for item: MenuBarItem) -> CGRect? {
        Bridging.getWindowFrame(for: item.windowID)
    }

    private func getEndPoint(for destination: MoveDestination) throws -> CGPoint {
        switch destination {
        case .leftOfItem(let targetItem):
            guard let frame = getCurrentFrame(for: targetItem) else {
                throw EventError(code: .invalidItem, item: targetItem)
            }
            return CGPoint(x: frame.minX, y: frame.midY)
        case .rightOfItem(let targetItem):
            guard let frame = getCurrentFrame(for: targetItem) else {
                throw EventError(code: .invalidItem, item: targetItem)
            }
            return CGPoint(x: frame.maxX, y: frame.midY)
        }
    }

    private func getFallbackPoint(for item: MenuBarItem) throws -> CGPoint {
        guard let frame = getCurrentFrame(for: item) else {
            throw EventError(code: .invalidItem, item: item)
        }
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    private func getTargetItem(for destination: MoveDestination) -> MenuBarItem {
        switch destination {
        case .leftOfItem(let target), .rightOfItem(let target): target
        }
    }

    private func itemHasCorrectPosition(
        item: MenuBarItem,
        for destination: MoveDestination,
        currentFrame: CGRect? = nil
    ) throws -> Bool {
        let itemFrame = currentFrame ?? getCurrentFrame(for: item)
        guard let itemFrame else {
            throw EventError(code: .invalidItem, item: item)
        }
        switch destination {
        case .leftOfItem(let target):
            guard let targetFrame = getCurrentFrame(for: target) else {
                throw EventError(code: .invalidItem, item: target)
            }
            return itemFrame.maxX == targetFrame.minX
        case .rightOfItem(let target):
            guard let targetFrame = getCurrentFrame(for: target) else {
                throw EventError(code: .invalidItem, item: target)
            }
            return itemFrame.minX == targetFrame.maxX
        }
    }

    private nonisolated func eventsMatch(_ events: [CGEvent], by integerFields: [CGEventField]) -> Bool {
        var fieldValues = Set<[Int64]>()
        for event in events {
            let values = integerFields.map(event.getIntegerValueField)
            fieldValues.insert(values)
            if fieldValues.count != 1 { return false }
        }
        return true
    }

    private nonisolated func postEvent(_ event: CGEvent, to location: EventTap.Location) {
        switch location {
        case .hidEventTap: event.post(tap: .cghidEventTap)
        case .sessionEventTap: event.post(tap: .cgSessionEventTap)
        case .annotatedSessionEventTap: event.post(tap: .cgAnnotatedSessionEventTap)
        case .pid(let pid): event.postToPid(pid)
        }
    }

    private func permitAllEvents(
        for stateID: CGEventSourceStateID,
        during states: [CGEventSuppressionState],
        suppressionInterval: TimeInterval,
        item: MenuBarItem
    ) throws {
        guard let source = CGEventSource(stateID: stateID) else {
            throw EventError(code: .invalidEventSource, item: item)
        }
        for state in states {
            source.setLocalEventsFilterDuringSuppressionState(.permitAllEvents, state: state)
        }
        source.localEventsSuppressionInterval = suppressionInterval
    }

    private func postEventAndWaitToReceive(
        _ event: CGEvent,
        to location: EventTap.Location,
        item: MenuBarItem
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let eventTap = EventTap(
                options: .listenOnly,
                location: location,
                place: .tailAppendEventTap,
                types: [event.type]
            ) { [weak self] proxy, type, rEvent in
                guard let self else {
                    proxy.disable()
                    return nil
                }
                if type == .tapDisabledByUserInput || type == .tapDisabledByTimeout {
                    proxy.enable()
                    return nil
                }
                guard self.eventsMatch([rEvent, event], by: CGEventField.menuBarItemEventFields) else {
                    return nil
                }
                guard proxy.isEnabled else { return nil }
                proxy.disable()
                continuation.resume()
                return nil
            }

            eventTap.enable(timeout: .milliseconds(50)) {
                eventTap.disable()
                continuation.resume(throwing: EventError(code: .eventOperationTimeout, item: item))
            }
            postEvent(event, to: location)
        }
    }

    private func scrombleEvent(
        _ event: CGEvent,
        from firstLocation: EventTap.Location,
        to secondLocation: EventTap.Location,
        item: MenuBarItem
    ) async throws {
        guard let nullEvent = CGEvent(source: nil) else {
            throw EventError(code: .eventCreationFailure, item: item)
        }
        let nullUserData = Int64(truncatingIfNeeded: Int(bitPattern: ObjectIdentifier(nullEvent)))
        nullEvent.setIntegerValueField(.eventSourceUserData, value: nullUserData)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let eventTap1 = EventTap(
                label: "EventTap.first",
                options: .defaultTap,
                location: firstLocation,
                place: .tailAppendEventTap,
                types: [nullEvent.type]
            ) { [weak self] proxy, type, rEvent in
                guard let self else {
                    proxy.disable()
                    return nil
                }
                if type == .tapDisabledByUserInput || type == .tapDisabledByTimeout {
                    proxy.enable()
                    return nil
                }
                guard rEvent.getIntegerValueField(.eventSourceUserData) == nullUserData else {
                    return nil
                }
                proxy.disable()
                self.postEvent(event, to: secondLocation)
                return nil
            }

            let eventTap2 = EventTap(
                label: "EventTap.second",
                options: .listenOnly,
                location: secondLocation,
                place: .tailAppendEventTap,
                types: [event.type]
            ) { [weak self] proxy, type, rEvent in
                guard let self else {
                    proxy.disable()
                    return nil
                }
                if type == .tapDisabledByUserInput || type == .tapDisabledByTimeout {
                    proxy.enable()
                    return nil
                }
                guard self.eventsMatch([rEvent, event], by: CGEventField.menuBarItemEventFields) else {
                    return nil
                }
                guard proxy.isEnabled else { return nil }
                proxy.disable()
                self.postEvent(event, to: firstLocation)
                continuation.resume()
                return nil
            }

            eventTap1.enable()
            eventTap2.enable(timeout: .milliseconds(50)) {
                eventTap1.disable()
                eventTap2.disable()
                continuation.resume(throwing: EventError(code: .eventOperationTimeout, item: item))
            }

            postEvent(nullEvent, to: firstLocation)
        }
    }

    private func scrombleEvent(
        _ event: CGEvent,
        from firstLocation: EventTap.Location,
        to secondLocation: EventTap.Location,
        waitingForFrameChangeOf item: MenuBarItem
    ) async throws {
        guard let initialFrame = getCurrentFrame(for: item) else {
            try await scrombleEvent(event, from: firstLocation, to: secondLocation, item: item)
            try await _Concurrency.Task.sleep(for: .milliseconds(50))
            return
        }
        try await scrombleEvent(event, from: firstLocation, to: secondLocation, item: item)
        try await waitForFrameChange(of: item, initialFrame: initialFrame, timeout: .milliseconds(80))
    }

    private func waitForFrameChange(of item: MenuBarItem, initialFrame: CGRect, timeout: Duration) async throws {
        struct CheckCancelled: Error { }
        let task = Task(timeout: timeout) { [weak self] in
            while true {
                try Task.checkCancellation()
                guard let frame = await self?.getCurrentFrame(for: item) else {
                    throw CheckCancelled()
                }
                if frame != initialFrame { return }
                try await _Concurrency.Task.sleep(for: .milliseconds(5))
            }
        }
        do {
            try await task.value
        } catch is CheckCancelled {
            try await _Concurrency.Task.sleep(for: .milliseconds(50))
        } catch is TaskTimeoutError {
            throw EventError(code: .frameCheckTimeout, item: item)
        }
    }
}

// MARK: - CGEvent helpers (Ice)

private enum MenuBarItemEventButtonState {
    case leftMouseDown, leftMouseUp
}

private enum MenuBarItemEventType {
    case move(MenuBarItemEventButtonState)

    var buttonState: MenuBarItemEventButtonState {
        switch self { case .move(let s): s }
    }

    var cgEventType: CGEventType {
        switch buttonState {
        case .leftMouseDown: .leftMouseDown
        case .leftMouseUp: .leftMouseUp
        }
    }

    var cgEventFlags: CGEventFlags {
        switch self {
        case .move(.leftMouseDown): .maskCommand
        case .move(.leftMouseUp): []
        }
    }

    var mouseButton: CGMouseButton {
        .left
    }
}

private extension CGEventField {
    static let windowID = CGEventField(rawValue: 0x33)! // swiftlint:disable:this force_unwrapping

    static let menuBarItemEventFields: [CGEventField] = [
        .eventSourceUserData,
        .mouseEventWindowUnderMousePointer,
        .mouseEventWindowUnderMousePointerThatCanHandleThisEvent,
        .windowID
    ]
}

private extension CGEventFilterMask {
    static let permitAllEvents: CGEventFilterMask = [
        .permitLocalMouseEvents,
        .permitLocalKeyboardEvents,
        .permitSystemDefinedEvents
    ]
}

private extension CGEvent {
    class func menuBarItemEvent(
        type: MenuBarItemEventType,
        location: CGPoint,
        item: MenuBarItem,
        pid: pid_t,
        source: CGEventSource
    ) -> CGEvent? {
        let mouseType = type.cgEventType
        let mouseButton = type.mouseButton

        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: mouseType,
            mouseCursorPosition: location,
            mouseButton: mouseButton
        ) else { return nil }

        event.flags = type.cgEventFlags

        let targetPID = Int64(pid)
        let userData = Int64(truncatingIfNeeded: Int(bitPattern: ObjectIdentifier(event)))
        let windowID = Int64(item.windowID)

        event.setIntegerValueField(.eventTargetUnixProcessID, value: targetPID)
        event.setIntegerValueField(.eventSourceUserData, value: userData)
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: windowID)
        event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: windowID)
        event.setIntegerValueField(.windowID, value: windowID)
        return event
    }
}

private extension Logger {
    static let itemMover = Logger(category: "MenuBarItemMover")
}
