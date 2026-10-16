import AppKit
import SwiftUI

/// Stable identifiers map only to owner-approved, bundled renditions. No bundle
/// writes, profile activation, downloads or activation-policy changes occur here.
@objc final class IconPreferences: NSObject {
    @objc static let shared = IconPreferences(defaults: .standard)
    static let changed = Notification.Name("GasMaskMenuBarIconChanged")
    static let symbols = ["mask", "balloon"]
    static let palettes = ["heritage", "cobalt", "slate", "pine", "sunset-sky", "fire-sky", "bandera"]
    private let defaults: UserDefaults
    private let dockSink: (NSImage) -> Void
    private var observer: NSObjectProtocol?
    private var lastMenu: String?
    private var lastDock: String?

    init(defaults: UserDefaults, dockSink: @escaping (NSImage) -> Void = {
        NSApp.applicationIconImage = $0
        NSApp.dockTile.display()
    }) {
        self.defaults = defaults
        self.dockSink = dockSink
        super.init()
        // Consolidate the former independent choices once. Preserve the Dock
        // silhouette when they differ; palette and Dock visibility stay intact.
        if defaults.object(forKey: "iconSymbol") == nil {
            let previous = ["dockIcon", "menuBarIcon"].compactMap { defaults.string(forKey: $0) }
            defaults.set(previous.first(where: Self.symbols.contains) ?? "mask", forKey: "iconSymbol")
        }
        observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
            object: nil, queue: .main) { [weak self] _ in self?.apply() }
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

    var symbol: String { Self.symbols.contains(defaults.string(forKey: "iconSymbol") ?? "") ? defaults.string(forKey: "iconSymbol")! : "mask" }
    var menuSymbol: String { symbol }
    var dockSymbol: String { symbol }
    var dockPalette: String { Self.palettes.contains(defaults.string(forKey: "dockPalette") ?? "") ? defaults.string(forKey: "dockPalette")! : "heritage" }
    var dockAssetName: String { "Dock_\(dockSymbol)_\(dockPalette.replacingOccurrences(of: "-", with: "_"))" }

    @objc var menuBarImage: NSImage {
        let name = menuSymbol == "balloon" ? "MenuBalloon" : "MenuMask"
        let image = (NSImage(named: name) ?? NSImage(named: "MenuMask"))!.copy() as! NSImage
        image.isTemplate = true
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    @objc func apply() {
        precondition(Thread.isMainThread)
        if lastDock != dockAssetName {
            applyDockIcon()
        }
        if lastMenu != menuSymbol {
            lastMenu = menuSymbol
            NotificationCenter.default.post(name: Self.changed, object: self)
        }
    }

    func applySelection(symbol: String, palette: String) {
        guard Self.symbols.contains(symbol), Self.palettes.contains(palette) else { return }
        defaults.set(symbol, forKey: "iconSymbol")
        defaults.set(palette, forKey: "dockPalette")
        // Apply is explicit: refresh even if a Dock/activation-policy transition
        // replaced the image after our last preference notification.
        applyDockIcon()
        apply()
    }

    @objc func applyDockIcon() {
        precondition(Thread.isMainThread)
        guard let image = NSImage(named: dockAssetName) ?? NSImage(named: "Dock_mask_heritage") else { return }
        lastDock = dockAssetName
        dockSink(image)
    }
}

struct IconSettingsView: View {
    @State private var symbol = IconPreferences.shared.symbol
    @State private var palette = IconPreferences.shared.dockPalette
    @State private var applied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Picker("Icon", selection: $symbol) {
                    Text("Mask").tag("mask")
                    Text("Balloon").tag("balloon")
                }
                .fixedSize()
                .accessibilityIdentifier("icon-symbol-picker")
                Picker("Color", selection: $palette) {
                    ForEach(IconPreferences.palettes, id: \.self) { value in
                        Text(value.split(separator: "-").map { $0.capitalized }.joined(separator: " ")).tag(value)
                    }
                }
                .fixedSize()
                .accessibilityIdentifier("icon-color-picker")
                Spacer(minLength: 0)
                Image("Dock_\(symbol)_\(palette.replacingOccurrences(of: "-", with: "_"))")
                    .resizable().interpolation(.high).frame(width: 32, height: 32)
                    .accessibilityLabel("Selected icon preview")
                Button("Apply") {
                    IconPreferences.shared.applySelection(symbol: symbol, palette: palette)
                    applied = true
                }
                .accessibilityIdentifier("apply-icon")
                .help("Apply the icon to the menu bar and Dock and save this choice")
            }
            Text(applied ? "Applied to the menu bar and Dock. Finder uses the installed app icon."
                         : "Menu bar and Dock icon. Finder uses the installed app icon.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .pickerStyle(.menu)
        .onChange(of: symbol) { _ in applied = false }
        .onChange(of: palette) { _ in applied = false }
    }
}
