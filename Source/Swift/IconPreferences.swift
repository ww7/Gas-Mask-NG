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

    init(defaults: UserDefaults, dockSink: @escaping (NSImage) -> Void = { NSApp.applicationIconImage = $0 }) {
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
            object: defaults, queue: .main) { [weak self] _ in self?.apply() }
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

    @objc func applyDockIcon() {
        precondition(Thread.isMainThread)
        guard let image = NSImage(named: dockAssetName) ?? NSImage(named: "Dock_mask_heritage") else { return }
        lastDock = dockAssetName
        dockSink(image)
    }
}

struct IconSettingsView: View {
    @AppStorage("iconSymbol") private var symbol = "mask"
    @AppStorage("dockPalette") private var palette = "heritage"

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image("Dock_\(IconPreferences.symbols.contains(symbol) ? symbol : "mask")_\((IconPreferences.palettes.contains(palette) ? palette : "heritage").replacingOccurrences(of: "-", with: "_"))")
                .resizable().interpolation(.high).frame(width: 48, height: 48)
                .accessibilityHidden(true)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Icon").gridColumnAlignment(.trailing)
                    Picker("Icon", selection: $symbol) {
                        Text("Mask").tag("mask")
                        Text("Balloon").tag("balloon")
                    }
                    .labelsHidden().frame(maxWidth: .infinity)
                    .help("Use the same symbol in the menu bar and Dock")
                }
                GridRow {
                    Text("Icon Color Scheme")
                    Picker("Icon Color Scheme", selection: $palette) {
                        Text("Heritage").tag("heritage")
                        Text("Cobalt").tag("cobalt")
                        Text("Slate").tag("slate")
                        Text("Pine").tag("pine")
                        Text("Sunset Sky").tag("sunset-sky")
                        Text("Fire Sky").tag("fire-sky")
                        Text("Bandera").tag("bandera")
                    }
                    .labelsHidden().frame(maxWidth: .infinity)
                    .help("Colors apply to the Dock; the menu bar follows macOS automatically")
                }
            }
        }
        .pickerStyle(.menu)
        .onChange(of: symbol) { _ in IconPreferences.shared.apply() }
        .onChange(of: palette) { _ in IconPreferences.shared.apply() }
    }
}
