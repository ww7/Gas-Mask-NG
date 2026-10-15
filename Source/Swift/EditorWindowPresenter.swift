import Cocoa
import SwiftUI

@objc final class EditorWindowPresenter: NSObject, NSWindowDelegate {

    private static var instance: EditorWindowPresenter?

    private let window: NSWindow
    private let store: HostsDataStore
    private let defaults: UserDefaults
    private var toolbarObservation: NSKeyValueObservation?
    private var displayModeObservation: NSKeyValueObservation?
    private var toolbarItemObserver: NSObjectProtocol?
    private weak var observedToolbar: NSToolbar?
    static let toolbarDisplayModeKey = "editorToolbarDisplayMode"

    private init(window: NSWindow, store: HostsDataStore, defaults: UserDefaults) {
        self.window = window
        self.store = store
        self.defaults = defaults
        super.init()
        window.delegate = self
        toolbarObservation = window.observe(\.toolbar, options: [.initial, .new]) { [weak self] _, _ in
            self?.configureToolbar()
        }
    }

    @objc static func editorWindowVisible() -> Bool {
        instance?.window.isVisible == true
    }

    private var documentEditor: HostsTextView? {
        func find(_ view: NSView) -> HostsTextView? {
            if let editor = view as? HostsTextView { return editor }
            return view.subviews.lazy.compactMap(find).first
        }
        return window.contentView.flatMap(find)
    }

    @objc static func findInEditor(_ sender: Any?) {
        guard let instance, let editor = instance.documentEditor else { return }
        instance.window.makeFirstResponder(editor)
        editor.performTextFinderAction(sender)
    }

    @objc static func showGlobalSearch() { instance?.store.showingGlobalSearch = true }
    @objc static func showHelp() { instance?.store.showingHelp = true }

    @objc static func createEditorWindow() -> NSWindow {
        makeEditorWindow(store: HostsDataStore(), frameAutosaveName: "editor_window")
    }

    static func makeEditorWindow(store: HostsDataStore, frameAutosaveName: String = "", defaults: UserDefaults = .standard) -> NSWindow {
        let editorView = EditorView(store: store)
        let hostingController = NSHostingController(rootView: editorView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Gas Mask"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.toolbarStyle = .expanded
        window.setContentSize(NSSize(width: 619, height: 479))
        window.minSize = NSSize(width: 400, height: 400)
        window.isReleasedWhenClosed = false
        if !frameAutosaveName.isEmpty {
            window.setFrameAutosaveName(frameAutosaveName)
        }

        let presenter = EditorWindowPresenter(window: window, store: store, defaults: defaults)
        instance = presenter

        return window
    }

    private func configureToolbar() {
        guard let toolbar = window.toolbar, toolbar !== observedToolbar else { return }
        displayModeObservation = nil
        if let toolbarItemObserver { NotificationCenter.default.removeObserver(toolbarItemObserver) }
        observedToolbar = toolbar
        // AppKit positions navigation items before ordinary toolbar items.
        // SwiftUI's fixed spaces need the same role to stay between the leading
        // actions, otherwise icon-only mode merges them into one glass group.
        toolbar.items.forEach(Self.configureNavigationSpace)
        toolbarItemObserver = NotificationCenter.default.addObserver(
            forName: NSToolbar.willAddItemNotification, object: toolbar, queue: .main
        ) { notification in
            if let item = notification.userInfo?[NSToolbarUserInfoKey.itemKey] as? NSToolbarItem {
                Self.configureNavigationSpace(item)
            }
        }
        let savedMode = NSToolbar.DisplayMode(rawValue: UInt(defaults.integer(forKey: Self.toolbarDisplayModeKey)))
        toolbar.displayMode = savedMode.flatMap { $0 == .default ? nil : $0 } ?? .iconAndLabel
        displayModeObservation = toolbar.observe(\.displayMode, options: [.new]) { [weak self] toolbar, _ in
            guard toolbar.displayMode != .default else { return }
            self?.defaults.set(Int(toolbar.displayMode.rawValue), forKey: Self.toolbarDisplayModeKey)
        }
    }

    private static func configureNavigationSpace(_ item: NSToolbarItem) {
        if item.itemIdentifier == .space { item.isNavigational = true }
    }

    deinit {
        if let toolbarItemObserver { NotificationCenter.default.removeObserver(toolbarItemObserver) }
    }

    // MARK: - NSWindowDelegate

    func windowDidBecomeMain(_ notification: Notification) {
        configureToolbar()
        Preferences.setShowEditorWindow(true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        Preferences.setShowEditorWindow(false)
        return true
    }
}
