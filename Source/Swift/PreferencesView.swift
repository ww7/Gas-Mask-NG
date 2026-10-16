import SwiftUI

// Apply at launch and immediately after a settings change. A nil application
// appearance follows macOS automatically, including later system theme changes.
@objc final class AppAppearance: NSObject {
    @objc static func applyPreference() {
        switch UserDefaults.standard.string(forKey: "appAppearance") {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    @StateObject private var loginItemObserver = LoginItemObserver()
    @AppStorage("overrideExternalModifications") private var overrideExternalModifications = true
    @AppStorage("showNameInStatusBar") private var showNameInStatusBar = false
    @AppStorage("appAppearance") private var appAppearance = "system"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Appearance", selection: $appAppearance) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.menu)
            .onChange(of: appAppearance) { _ in AppAppearance.applyPreference() }
            Toggle("Open at Login", isOn: $loginItemObserver.isEnabled)
            Toggle("Override external modifications", isOn: $overrideExternalModifications)
            Toggle("Show Host File Name in Menu Bar", isOn: $showNameInStatusBar)
        }
    }
}

// MARK: - Editor Tab

struct EditorTab: View {
    @AppStorage("syntaxHighlighting") private var syntaxHighlighting = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Syntax Highlighting", isOn: $syntaxHighlighting)
        }
    }
}

// MARK: - Remote Tab

struct RemoteTab: View {
    @State private var sliderPosition: Double

    init() {
        let currentMinutes = Int(Preferences.remoteHostsUpdateInterval())
        _sliderPosition = State(initialValue: Double(RemoteIntervalMapper.position(forMinutes: currentMinutes)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Update interval:")

            Slider(value: $sliderPosition, in: 1...9, step: 1)
                .onChange(of: sliderPosition) { newValue in
                    let minutes = RemoteIntervalMapper.minutes(forPosition: Int(newValue))
                    Preferences.setRemoteHostsUpdateInterval(Int32(minutes))
                }

            HStack(spacing: 0) {
                ForEach(Array(RemoteIntervalMapper.labels.enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Hotkeys Tab

struct HotkeysTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Show / Hide Editor Window:")
                    .frame(width: 190, alignment: .trailing)
                ShortcutRecorderView(prefsKey: ShowEditorWindowHotkeyPrefKey)
                    .frame(width: 150, height: 25)
            }
            HStack {
                Text("Activate Previous File:")
                    .frame(width: 190, alignment: .trailing)
                ShortcutRecorderView(prefsKey: ActivatePreviousFilePrefKey)
                    .frame(width: 150, height: 25)
            }
            HStack {
                Text("Activate Next File:")
                    .frame(width: 190, alignment: .trailing)
                ShortcutRecorderView(prefsKey: ActivateNextFilePrefKey)
                    .frame(width: 150, height: 25)
            }
            HStack {
                Text("Update Remote Files:")
                    .frame(width: 190, alignment: .trailing)
                ShortcutRecorderView(prefsKey: UpdateAndSynchronizePrefKey)
                    .frame(width: 150, height: 25)
            }
        }
    }
}

// MARK: - Update Tab

struct UpdateTab: View {
    @StateObject private var sparkleObserver = SparkleObserver()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if Bundle.main.object(forInfoDictionaryKey: "WW7ForkBuild") as? Bool == true {
                Text("Updates for Gas Mask NG are available on GitHub.")
                Link("Open Releases", destination: URL(string: "https://github.com/ww7/gas-mask-ng/releases")!)
            } else {
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { sparkleObserver.automaticChecksEnabled },
                    set: { sparkleObserver.setAutomaticChecks($0) }
                ))

                Text(sparkleObserver.lastCheckDateFormatted)
                    .font(.caption)

                Button("Check Now") {
                    sparkleObserver.checkForUpdates()
                }
                .disabled(!sparkleObserver.canCheckForUpdates)
            }
        }
    }
}
