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
        observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
            object: defaults, queue: .main) { [weak self] _ in self?.apply() }
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

    var menuSymbol: String { Self.symbols.contains(defaults.string(forKey: "menuBarIcon") ?? "") ? defaults.string(forKey: "menuBarIcon")! : "mask" }
    var dockSymbol: String { Self.symbols.contains(defaults.string(forKey: "dockIcon") ?? "") ? defaults.string(forKey: "dockIcon")! : "mask" }
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
    @AppStorage("menuBarIcon") private var menuBar = "mask"
    @AppStorage("dockIcon") private var dock = "mask"
    @AppStorage("dockPalette") private var palette = "heritage"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Menu Bar Icon", selection: $menuBar) {
                Text("Mask").tag("mask")
                Text("Balloon").tag("balloon")
            }
            .onChange(of: menuBar) { _ in IconPreferences.shared.apply() }
            Picker("Dock Icon", selection: $dock) {
                Text("Mask").tag("mask")
                Text("Balloon").tag("balloon")
            }
            .onChange(of: dock) { _ in IconPreferences.shared.apply() }
            HStack(spacing: 12) {
                Picker("Dock Palette", selection: $palette) {
                    Text("Heritage").tag("heritage")
                    Text("Cobalt").tag("cobalt")
                    Text("Slate").tag("slate")
                    Text("Pine").tag("pine")
                    Text("Sunset Sky").tag("sunset-sky")
                    Text("Fire Sky").tag("fire-sky")
                    Text("Bandera").tag("bandera")
                }
                Image("Dock_\(IconPreferences.symbols.contains(dock) ? dock : "mask")_\((IconPreferences.palettes.contains(palette) ? palette : "heritage").replacingOccurrences(of: "-", with: "_"))")
                    .resizable().interpolation(.high).frame(width: 38, height: 38)
                    .accessibilityHidden(true)
            }
            .onChange(of: palette) { _ in IconPreferences.shared.apply() }
        }
        .pickerStyle(.menu)
    }
}
