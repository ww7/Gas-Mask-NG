import Foundation
import MASShortcut

/// Registers global keyboard shortcuts using `MASShortcutBinder`.
///
/// Replaces the old `GlobalHotkeys` ObjC class that used the Carbon Event Manager directly.
/// Call `GlobalShortcuts.shared` once at app launch to register all hotkeys.
@objc final class GlobalShortcuts: NSObject {
    @objc static let shared = GlobalShortcuts()

    private override init() {
        super.init()
        Self.migrateLegacyShortcuts()
        guard let binder = MASShortcutBinder.shared() else { return }
        binder.bindingOptions = [
            NSBindingOption.valueTransformerName.rawValue: MASDictionaryTransformerName
        ]

        binder.bindShortcut(withDefaultsKey: ShowEditorWindowHotkeyPrefKey) {
            DispatchQueue.main.async {
                guard let controller = ApplicationController.defaultInstance() else { return }
                if controller.editorWindowOpened() {
                    controller.closeEditorWindow(nil)
                } else {
                    controller.openEditorWindow(nil)
                }
            }
        }

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(refreshMenuShortcuts),
                       name: UserDefaults.didChangeNotification, object: UserDefaults.standard)
        // Notification names from Gas_Mask_Prefix.pch lines 42–44 (not importable in Swift)
        binder.bindShortcut(withDefaultsKey: ActivatePreviousFilePrefKey) {
            nc.post(name: .init("activatePreviousFileNotification"), object: nil)
        }
        binder.bindShortcut(withDefaultsKey: ActivateNextFilePrefKey) {
            nc.post(name: .init("activateNextFileNotification"), object: nil)
        }
        binder.bindShortcut(withDefaultsKey: UpdateAndSynchronizePrefKey) {
            nc.post(name: .init("updateAndSynchronizeNotification"), object: nil)
        }
        refreshMenuShortcuts()
    }
    // Keep display and registration on the same MASShortcut representation.
    // Pre-SwiftUI versions stored Carbon modifiers under a different key.
    private static func migrateLegacyShortcuts() {
        let defaults = UserDefaults.standard
        for key in [ShowEditorWindowHotkeyPrefKey, ActivatePreviousFilePrefKey,
                    ActivateNextFilePrefKey, UpdateAndSynchronizePrefKey] {
            guard let old = defaults.dictionary(forKey: key), old["modifierFlags"] == nil,
                  let code = old["keyCode"] as? Int, let carbon = old["modifiers"] as? UInt else { continue }
            var flags: NSEvent.ModifierFlags = []
            if carbon & 256 != 0 { flags.insert(.command) }
            if carbon & 512 != 0 { flags.insert(.shift) }
            if carbon & 2048 != 0 { flags.insert(.option) }
            if carbon & 4096 != 0 { flags.insert(.control) }
            defaults.set(["keyCode": code, "modifierFlags": flags.rawValue], forKey: key)
        }
    }

    @objc static func configureUpdateMenuItem(_ item: NSMenuItem) {
        let defaults = UserDefaults.standard
        let transformer = ValueTransformer(forName: NSValueTransformerName(rawValue: MASDictionaryTransformerName))
        let shortcut = transformer?.transformedValue(defaults.dictionary(forKey: UpdateAndSynchronizePrefKey)) as? MASShortcut
        item.keyEquivalent = shortcut?.keyCodeStringForKeyEquivalent?.lowercased() ?? ""
        item.keyEquivalentModifierMask = shortcut?.modifierFlags ?? []
    }

    @objc private func refreshMenuShortcuts() {
        func update(_ menu: NSMenu?) {
            for item in menu?.items ?? [] {
                if item.action == #selector(ApplicationController.updateAndSynchronize(_:)) {
                    Self.configureUpdateMenuItem(item)
                }
                update(item.submenu)
            }
        }
        update(NSApp.mainMenu)
    }

}
