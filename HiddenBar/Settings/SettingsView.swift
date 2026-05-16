import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var launchAtLogin: LaunchAtLoginManager
    @ObservedObject var appsCatalog: AppsCatalog

    var body: some View {
        TabView {
            GeneralTab(settings: settings, launchAtLogin: launchAtLogin)
                .tabItem { Label("General", systemImage: "gearshape") }
            PanelTab(settings: settings)
                .tabItem { Label("Panel", systemImage: "rectangle.bottomthird.inset.filled") }
            AppsTab(settings: settings, catalog: appsCatalog)
                .tabItem { Label("Apps", systemImage: "app.badge") }
        }
        .frame(width: 540, height: 480)
    }
}

private struct GeneralTab: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var launchAtLogin: LaunchAtLoginManager

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch HiddenBar at login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                if launchAtLogin.requiresApproval {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Approval required in System Settings.")
                            .font(.footnote)
                        Spacer()
                        Button("Open…") { launchAtLogin.openSystemSettings() }
                            .controlSize(.small)
                    }
                }
                if let error = launchAtLogin.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("Panel behavior") {
                Toggle("Auto-hide panel after delay", isOn: SettingsBindings.bind(settings, \.autoHideEnabled))

                LabeledContent("Auto-hide delay") {
                    HStack(spacing: 8) {
                        Slider(
                            value: SettingsBindings.bind(settings, \.autoHideDelay),
                            in: 1...30,
                            step: 1
                        )
                        Text("\(Int(settings.preferences.autoHideDelay))s")
                            .font(.callout.monospacedDigit())
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                .disabled(!settings.preferences.autoHideEnabled)

                Toggle("Avoid the camera notch", isOn: SettingsBindings.bind(settings, \.avoidNotch))
            }

            Section {
                LabeledContent("Version") {
                    Text(AppBundleInfo.versionString)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(.top, 4)
        .onAppear { launchAtLogin.refresh() }
    }
}

private struct PanelTab: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section("Position") {
                Picker("Anchor", selection: SettingsBindings.bind(settings, \.panelAnchor)) {
                    Text("Below toggle button").tag(PanelAnchorMode.belowToggle)
                    Text("Below right edge").tag(PanelAnchorMode.belowRightEdge)
                    Text("Custom offsets").tag(PanelAnchorMode.custom)
                }
                .pickerStyle(.menu)

                stepperRow(
                    title: "Horizontal offset",
                    value: SettingsBindings.bind(settings, \.panelHorizontalOffset),
                    range: -120...120,
                    step: 1,
                    suffix: "pt"
                )
                stepperRow(
                    title: "Vertical offset",
                    value: SettingsBindings.bind(settings, \.panelVerticalOffset),
                    range: -40...40,
                    step: 1,
                    suffix: "pt"
                )
            }

            Section("Layout") {
                LabeledContent("Items per row") {
                    Stepper(
                        value: SettingsBindings.bindInt(settings, \.maxItemsPerRow),
                        in: 1...16
                    ) {
                        Text("\(settings.preferences.maxItemsPerRow)")
                            .font(.callout.monospacedDigit())
                    }
                    .frame(width: 110)
                }

                sliderRow(
                    title: "Item size",
                    value: SettingsBindings.bind(settings, \.itemSize),
                    range: 28...52,
                    step: 1,
                    suffix: "pt"
                )
                sliderRow(
                    title: "Item spacing",
                    value: SettingsBindings.bind(settings, \.itemSpacing),
                    range: 2...16,
                    step: 1,
                    suffix: "pt"
                )
                sliderRow(
                    title: "Row spacing",
                    value: SettingsBindings.bind(settings, \.rowSpacing),
                    range: 2...16,
                    step: 1,
                    suffix: "pt"
                )
                sliderRow(
                    title: "Panel padding",
                    value: SettingsBindings.bind(settings, \.panelPadding),
                    range: 4...24,
                    step: 1,
                    suffix: "pt"
                )
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func sliderRow(
        title: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        step: CGFloat.Stride,
        suffix: String
    ) -> some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                Slider(value: value, in: range, step: step)
                Text("\(Int(value.wrappedValue))\(suffix)")
                    .font(.callout.monospacedDigit())
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private func stepperRow(
        title: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        step: CGFloat.Stride,
        suffix: String
    ) -> some View {
        LabeledContent(title) {
            Stepper(value: value, in: range, step: step) {
                Text("\(Int(value.wrappedValue))\(suffix)")
                    .font(.callout.monospacedDigit())
            }
            .frame(width: 130)
        }
    }
}

@MainActor
enum SettingsBindings {
    static func bind<V>(_ store: SettingsStore, _ keyPath: WritableKeyPath<AppPreferences, V>) -> Binding<V> {
        Binding(
            get: { store.preferences[keyPath: keyPath] },
            set: { newValue in
                store.update { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    static func bindInt(_ store: SettingsStore, _ keyPath: WritableKeyPath<AppPreferences, Int>) -> Binding<Int> {
        bind(store, keyPath)
    }
}

private enum AppBundleInfo {
    static var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
