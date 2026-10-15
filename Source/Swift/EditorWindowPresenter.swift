import Cocoa
import SwiftUI

@objc final class EditorWindowPresenter: NSObject, NSWindowDelegate {

    private static var instance: EditorWindowPresenter?

    private let window: NSWindow

    private init(window: NSWindow) {
        self.window = window
        super.init()
        window.delegate = self
    }

    @objc static func createEditorWindow() -> NSWindow {
        makeEditorWindow(store: HostsDataStore(), frameAutosaveName: "editor_window")
    }

    static func makeEditorWindow(store: HostsDataStore, frameAutosaveName: String = "") -> NSWindow {
        let editorView = EditorView(store: store)
        let hostingController = NSHostingController(rootView: editorView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Gas Mask"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.toolbarStyle = .expanded
        window.toolbar?.displayMode = .iconAndLabel
        window.setContentSize(NSSize(width: 619, height: 479))
        window.minSize = NSSize(width: 400, height: 400)
        window.isReleasedWhenClosed = false
        if !frameAutosaveName.isEmpty {
            window.setFrameAutosaveName(frameAutosaveName)
        }

        let presenter = EditorWindowPresenter(window: window)
        instance = presenter

        return window
    }

    // MARK: - NSWindowDelegate

    func windowDidBecomeMain(_ notification: Notification) {
        window.toolbar?.displayMode = .iconAndLabel
        Preferences.setShowEditorWindow(true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        Preferences.setShowEditorWindow(false)
        return true
    }
}
