import AppKit
import Combine
import SwiftUI

@MainActor
final class AppsCatalog: ObservableObject {
    struct DetectedApp: Identifiable, Hashable {
        let identifier: String
        let displayName: String
        let bundleIdentifier: String?
        let ownerName: String
        let title: String?
        let icon: NSImage?

        var id: String { identifier }

        static func == (lhs: DetectedApp, rhs: DetectedApp) -> Bool { lhs.identifier == rhs.identifier }
        func hash(into hasher: inout Hasher) { hasher.combine(identifier) }
    }

    typealias ItemsSampler = (@escaping ([MenuBarItem], NSScreen?) -> Void) -> Void

    @Published private(set) var detectedItems: [DetectedApp] = []

    private let enumerator: MenuBarItemEnumerator
    private let capture: MenuBarItemImageCapture
    var itemsSampler: ItemsSampler?

    init(enumerator: MenuBarItemEnumerator, capture: MenuBarItemImageCapture) {
        self.enumerator = enumerator
        self.capture = capture
    }

    func refresh() {
        if let sampler = itemsSampler {
            sampler { [weak self] items, _ in
                self?.applyDetectedItems(items)
            }
        } else if let screen = NSScreen.main {
            applyDetectedItems(enumerator.currentItems(on: screen))
        }
    }

    func startAutoRefresh() {
        refresh()
    }

    func stopAutoRefresh() { }

    private func applyDetectedItems(_ items: [MenuBarItem]) {
        var seen: Set<String> = []
        var ordered: [MenuBarItem] = []
        for item in items {
            guard item.isMovable else { continue }
            let key = item.canonicalIdentifier
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            ordered.append(item)
        }

        Task { [weak self] in
            guard let self else { return }
            let images = await self.capture.captureImages(for: ordered)
            await MainActor.run {
                var apps: [DetectedApp] = []
                for item in ordered {
                    let cgImage = images[item.windowID]
                    let icon: NSImage? = cgImage.map { cg in
                        NSImage(cgImage: cg, size: NSSize(width: 22, height: 22))
                    }
                    apps.append(DetectedApp(
                        identifier: item.canonicalIdentifier,
                        displayName: item.displayName,
                        bundleIdentifier: item.bundleIdentifier,
                        ownerName: item.ownerName,
                        title: item.title,
                        icon: icon
                    ))
                }
                apps.sort { lhs, rhs in
                    if lhs.displayName == rhs.displayName {
                        return lhs.identifier < rhs.identifier
                    }
                    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }
                if apps != self.detectedItems {
                    self.detectedItems = apps
                }
            }
        }
    }
}

@MainActor
struct AppsTab: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var catalog: AppsCatalog

    var body: some View {
        Form {
            Section {
                if catalog.detectedItems.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("No menu bar items detected yet. Make sure HiddenBar has Screen Recording and Accessibility permission, then click Refresh.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(catalog.detectedItems) { app in
                        row(for: app)
                    }
                }
            } header: {
                HStack {
                    Text("Apps detected in the menu bar")
                    Spacer()
                    Button {
                        catalog.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            } footer: {
                Text("Toggling “Always show” will move the app's status item next to the « toggle so it stays visible. Requires Accessibility permission.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(.top, 4)
        .onAppear { catalog.startAutoRefresh() }
        .onDisappear { catalog.stopAutoRefresh() }
    }

    @ViewBuilder
    private func row(for app: AppsCatalog.DetectedApp) -> some View {
        HStack(spacing: 10) {
            iconView(app: app)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .font(.body)
                if let bundleID = app.bundleIdentifier {
                    Text(bundleID)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                } else {
                    Text(app.ownerName)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: binding(for: app.identifier))
                .labelsHidden()
        }
    }

    @ViewBuilder
    private func iconView(app: AppsCatalog.DetectedApp) -> some View {
        if let icon = app.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 26, height: 26)
        } else {
            Image(systemName: "square.dashed")
                .resizable()
                .frame(width: 22, height: 22)
                .foregroundStyle(.secondary)
        }
    }

    private func binding(for identifier: String) -> Binding<Bool> {
        Binding(
            get: { settings.preferences.alwaysVisibleApps.contains(identifier) },
            set: { newValue in
                settings.update {
                    if newValue {
                        $0.alwaysVisibleApps.insert(identifier)
                    } else {
                        $0.alwaysVisibleApps.remove(identifier)
                    }
                }
            }
        )
    }
}
