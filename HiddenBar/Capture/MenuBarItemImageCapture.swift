import AppKit
import CoreGraphics
import ScreenCaptureKit

@MainActor
final class MenuBarItemImageCapture {
    private struct CacheKey: Hashable {
        let windowID: CGWindowID
        let widthBucket: Int
    }

    private var cache: [CacheKey: CGImage] = [:]

    init() {}

    func clearCache() {
        cache.removeAll()
    }

    func captureImages(for items: [MenuBarItem]) async -> [CGWindowID: CGImage] {
        guard !items.isEmpty else { return [:] }

        var results: [CGWindowID: CGImage] = [:]
        var missing: [MenuBarItem] = []

        for item in items {
            let key = Self.makeKey(item: item)
            if let cached = cache[key] {
                results[item.windowID] = cached
            } else {
                missing.append(item)
            }
        }

        guard !missing.isEmpty else { return results }

        for item in missing {
            if let image = captureUsingLegacyAPI(item: item) {
                cache[Self.makeKey(item: item)] = image
                results[item.windowID] = image
            }
        }

        if results.count < items.count {
            await captureViaScreenCaptureKit(items: items.filter { results[$0.windowID] == nil }, into: &results)
        }

        return results
    }

    private func captureUsingLegacyAPI(item: MenuBarItem) -> CGImage? {
        let listOption: UInt32 = 1 << 3   // kCGWindowListOptionIncludingWindow
        let imageOption: UInt32 = (1 << 0) | (1 << 1)  // boundsIgnoreFraming | bestResolution
        guard let unmanaged = legacyCGWindowListCreateImage(
            .null,
            listOption,
            item.windowID,
            imageOption
        ) else { return nil }
        let image = unmanaged.takeRetainedValue()
        guard image.width > 0, image.height > 0 else { return nil }
        return image
    }

    private func captureViaScreenCaptureKit(
        items: [MenuBarItem],
        into results: inout [CGWindowID: CGImage]
    ) async {
        guard !items.isEmpty else { return }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            let scale = NSScreen.main?.backingScaleFactor ?? 2
            for item in items {
                guard let window = content.windows.first(where: { $0.windowID == item.windowID }) else { continue }
                let filter = SCContentFilter(desktopIndependentWindow: window)
                let configuration = SCStreamConfiguration()
                configuration.width = Int((item.frame.width * scale).rounded(.up))
                configuration.height = Int((item.frame.height * scale).rounded(.up))
                configuration.scalesToFit = true
                configuration.showsCursor = false
                do {
                    let image = try await SCScreenshotManager.captureImage(
                        contentFilter: filter,
                        configuration: configuration
                    )
                    cache[Self.makeKey(item: item)] = image
                    results[item.windowID] = image
                } catch {
                    Logger.capture.debug("SCK capture failed for windowID \(item.windowID): \(error.localizedDescription)")
                }
            }
        } catch {
            Logger.capture.debug("SCShareableContent unavailable: \(error.localizedDescription)")
        }
    }

    private static func makeKey(item: MenuBarItem) -> CacheKey {
        CacheKey(windowID: item.windowID, widthBucket: Int(item.frame.width.rounded()))
    }
}

@_silgen_name("CGWindowListCreateImage")
private func legacyCGWindowListCreateImage(
    _ screenBounds: CGRect,
    _ listOption: UInt32,
    _ windowID: CGWindowID,
    _ imageOption: UInt32
) -> Unmanaged<CGImage>?
