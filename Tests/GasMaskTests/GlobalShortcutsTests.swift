import XCTest
import MASShortcut
@testable import Gas_Mask

final class GlobalShortcutsTests: XCTestCase {

    func testShared_returnsSameInstance() {
        let a = GlobalShortcuts.shared
        let b = GlobalShortcuts.shared
        XCTAssertTrue(a === b, "GlobalShortcuts.shared should return the same instance")
    }

    func testShared_isNotNil() {
        XCTAssertNotNil(GlobalShortcuts.shared)
    }

    func testBinder_hasBindingOptionsSet() {
        _ = GlobalShortcuts.shared
        let binder = MASShortcutBinder.shared()
        XCTAssertNotNil(binder)
        let options = binder?.bindingOptions
        XCTAssertNotNil(options, "Binder should have bindingOptions set")
        let transformerName = options?[NSBindingOption.valueTransformerName.rawValue] as? String
        XCTAssertEqual(transformerName, MASDictionaryTransformerName,
                       "Binder should use MASDictionaryTransformerName")
    }

    func testActivatePreviousFile_registersShortcut() {
        _ = GlobalShortcuts.shared
        assertShortcutRegistered(forDefaultsKey: ActivatePreviousFilePrefKey)
    }

    func testActivateNextFile_registersShortcut() {
        _ = GlobalShortcuts.shared
        assertShortcutRegistered(forDefaultsKey: ActivateNextFilePrefKey)
    }

    func testUpdateAndSynchronize_registersShortcut() {
        _ = GlobalShortcuts.shared
        assertShortcutRegistered(forDefaultsKey: UpdateAndSynchronizePrefKey)
    }

    func testRemoteShortcut_isRegisteredAndShownInMenus() throws {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: UpdateAndSynchronizePrefKey)
        defer { defaults.set(previous, forKey: UpdateAndSynchronizePrefKey) }
        _ = GlobalShortcuts.shared
        let shortcut = MASShortcut(keyCode: Int(kVK_F5), modifierFlags: [.control, .shift, .command])
        let transformer = try XCTUnwrap(ValueTransformer(forName: .init(rawValue: MASDictionaryTransformerName)))
        let item = NSMenuItem(title: "Update Remote Files", action: NSSelectorFromString("updateAndSynchronize:"), keyEquivalent: "")
        let menu = NSMenu(title: "Test")
        menu.addItem(item)
        let root = NSMenuItem(title: "Test", action: nil, keyEquivalent: "")
        root.submenu = menu
        NSApp.mainMenu?.addItem(root)
        defer { NSApp.mainMenu?.removeItem(root) }
        defaults.set(transformer.reverseTransformedValue(shortcut), forKey: UpdateAndSynchronizePrefKey)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertTrue(MASShortcutBinder.shared()!.shortcutMonitor.isShortcutRegistered(shortcut))
        XCTAssertEqual(item.keyEquivalent, shortcut.keyCodeStringForKeyEquivalent?.lowercased())
        XCTAssertEqual(item.keyEquivalentModifierMask, shortcut.modifierFlags)
        let statusMenuItem = NSMenuItem()
        GlobalShortcuts.configureUpdateMenuItem(statusMenuItem)
        XCTAssertEqual(statusMenuItem.keyEquivalent, item.keyEquivalent)
        defaults.set([String: Int](), forKey: UpdateAndSynchronizePrefKey)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(item.keyEquivalent, "", "Clearing a shortcut must clear the displayed equivalent")
        XCTAssertEqual(item.keyEquivalentModifierMask, [])
        XCTAssertFalse(MASShortcutBinder.shared()!.shortcutMonitor.isShortcutRegistered(shortcut))
    }

    // MARK: - Helpers

    /// Writes a shortcut to UserDefaults, waits for MASShortcutBinder to pick
    /// it up via KVO, and verifies the shortcut is registered with the monitor.
    private func assertShortcutRegistered(
        forDefaultsKey defaultsKey: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard let binder = MASShortcutBinder.shared() else {
            XCTFail("MASShortcutBinder.shared() returned nil", file: file, line: line)
            return
        }

        // Create a test shortcut (Ctrl+Shift+Cmd+F5) and write to UserDefaults
        // using the same dictionary transformer the binder expects.
        let shortcut = MASShortcut(keyCode: Int(kVK_F5),
                                   modifierFlags: [.control, .shift, .command])
        let transformer = ValueTransformer(forName: .init(rawValue: MASDictionaryTransformerName))
        let encoded = transformer?.reverseTransformedValue(shortcut)
        UserDefaults.standard.set(encoded, forKey: defaultsKey)

        // Give KVO a chance to propagate.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        // Verify the monitor registered the shortcut.
        let registered = binder.shortcutMonitor.isShortcutRegistered(shortcut)
        XCTAssertTrue(registered,
                      "Shortcut should be registered for key '\(defaultsKey)'",
                      file: file, line: line)

        // Clean up: remove the test shortcut to avoid side effects.
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }
}
