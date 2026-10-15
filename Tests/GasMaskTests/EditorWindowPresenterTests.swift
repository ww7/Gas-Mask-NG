import XCTest
import SwiftUI
@testable import Gas_Mask

final class EditorWindowPresenterTests: XCTestCase {

    private var window: NSWindow!

    override func setUp() {
        super.setUp()
        window = EditorWindowPresenter.createEditorWindow()
    }

    override func tearDown() {
        window.orderOut(nil)
        window = nil
        super.tearDown()
    }

    func testWindowTitle() {
        XCTAssertEqual(window.title, "Gas Mask")
    }

    func testFrameAutosaveName() {
        XCTAssertEqual(window.frameAutosaveName, "editor_window")
    }

    func testMinSize() {
        // Width should match the configured minimum.
        // Height may be larger than 400 due to SwiftUI content minimum sizing.
        XCTAssertEqual(window.minSize.width, 400)
        XCTAssertGreaterThanOrEqual(window.minSize.height, 400)
    }

    func testStyleMask_containsExpectedOptions() {
        let mask = window.styleMask
        XCTAssertTrue(mask.contains(.titled))
        XCTAssertTrue(mask.contains(.closable))
        XCTAssertTrue(mask.contains(.miniaturizable))
        XCTAssertTrue(mask.contains(.resizable))
    }

    func testContentViewController_exists() {
        XCTAssertNotNil(window.contentViewController)
    }

    func testWindowDelegate_exists() {
        XCTAssertNotNil(window.delegate)
    }

    func testSidebar_compactNeutralSelectionAndCombinedFirst() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("gasmask-sidebar-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let localURL = directory.appendingPathComponent("Local Fixture.hst")
        try "127.0.0.1 example.test".write(to: localURL, atomically: true, encoding: .utf8)
        let local = try XCTUnwrap(Hosts(path: localURL.path))
        let combinedURL = directory.appendingPathComponent("Combined Fixture.hst")
        try "".write(to: combinedURL, atomically: true, encoding: .utf8)
        let combined = try XCTUnwrap(CombinedHosts(path: combinedURL.path, allHostsFiles: [local]))
        let localGroup = try XCTUnwrap(HostsGroup(name: "LOCAL"))
        localGroup.children = [local]
        let combinedGroup = try XCTUnwrap(HostsGroup(name: "COMBINED"))
        combinedGroup.children = [combined]
        let store = HostsDataStore()
        store.hostsGroups = [localGroup, combinedGroup]
        store.selectedHosts = combined
        let preview = NSWindow(contentViewController: NSHostingController(rootView: SidebarView(store: store)))
        preview.setContentSize(NSSize(width: 220, height: 250))
        preview.makeKeyAndOrderFront(nil)
        defer { preview.orderOut(nil) }
        func settle() {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
            preview.contentView?.layoutSubtreeIfNeeded()
        }
        func descendants(_ view: NSView) -> [NSView] {
            [view] + view.subviews.flatMap(descendants)
        }
        settle()
        let content = try XCTUnwrap(preview.contentView)
        let table = try XCTUnwrap(descendants(content).compactMap { $0 as? NSTableView }.first)
        XCTAssertEqual(table.selectionHighlightStyle, .none)
        XCTAssertEqual(table.selectedRow, 1, "Combined must be first, after its section header")
        XCTAssertLessThanOrEqual(table.rect(ofRow: table.selectedRow).height, 22)
        XCTAssertEqual(table.intercellSpacing.height, 0)
        store.renamingHosts = combined
        settle()
        XCTAssertEqual(table.selectionHighlightStyle, .none, "Renaming must not restore the native blue row highlight")
        XCTAssertTrue(preview.firstResponder is NSTextView, "Inline name must receive text focus")
        let output = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/ui-qa/sidebar-rename.png")
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bitmap = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: content.bounds))
        content.cacheDisplay(in: content.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output)
    }

    func testRename_endsOnBlurAndSubmitFocusesDocument() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("gasmask-rename-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("New Profile.hst")
        try "127.0.0.1 fixture.example.test".write(to: path, atomically: true, encoding: .utf8)
        let hosts = try XCTUnwrap(Hosts(path: path.path))
        let main = try XCTUnwrap(HostsMainController.defaultInstance())
        let previousControllers = main.value(forKey: "controllers")
        let previousContent = main.content
        defer {
            main.setValue(previousControllers, forKey: "controllers")
            main.content = previousContent
        }
        let controller = LocalHostsController()
        controller.hostsFiles.add(hosts)
        let group = try XCTUnwrap(controller.hostsGroup())
        group.children = [hosts]
        main.setValue([controller], forKey: "controllers")
        main.content = [group]
        let store = HostsDataStore()
        store.selectedHosts = hosts
        let preview = EditorWindowPresenter.makeEditorWindow(store: store)
        preview.makeKeyAndOrderFront(nil)
        defer { preview.orderOut(nil) }
        func settle() {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
            preview.contentView?.layoutSubtreeIfNeeded()
        }
        func descendants(_ view: NSView) -> [NSView] {
            [view] + view.subviews.flatMap(descendants)
        }
        settle()
        let content = try XCTUnwrap(preview.contentView)
        let editor = try XCTUnwrap(descendants(content).compactMap { $0 as? HostsTextView }.first)
        func beginRename(_ name: String) throws -> NSTextView {
            NotificationCenter.default.post(name: .hostsFileShouldBeRenamed, object: hosts)
            settle()
            let fieldEditor = try XCTUnwrap(preview.firstResponder as? NSTextView)
            XCTAssertFalse(fieldEditor === editor)
            fieldEditor.insertText(name, replacementRange: NSRange(location: 0, length: (fieldEditor.string as NSString).length))
            settle()
            return fieldEditor
        }
        // New-file rename: leaving for the document commits and restores the row.
        _ = try beginRename("Blur Renamed")
        XCTAssertTrue(preview.makeFirstResponder(editor))
        settle()
        XCTAssertNil(store.renamingHosts)
        XCTAssertEqual(hosts.name(), "Blur Renamed")
        XCTAssertTrue(preview.firstResponder === editor)
        XCTAssertEqual(store.editorFocusRequest, 0, "Blur must not redirect the clicked focus target")
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(hosts.path)))

        let submitted = try beginRename("Submit Renamed")
        submitted.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        settle()
        XCTAssertNil(store.renamingHosts)
        XCTAssertEqual(hosts.name(), "Submit Renamed")
        XCTAssertTrue(preview.firstResponder === editor)
        XCTAssertEqual(store.editorFocusRequest, 1, "Return must finish only once")

        let cancelled = try beginRename("Discard This Name")
        cancelled.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        settle()
        XCTAssertNil(store.renamingHosts)
        XCTAssertEqual(hosts.name(), "Submit Renamed")
        XCTAssertEqual(store.editorFocusRequest, 1)

        let table = try XCTUnwrap(descendants(content).compactMap { $0 as? NSTableView }.first)
        XCTAssertTrue(preview.makeFirstResponder(table))
        let enter = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: preview.windowNumber,
            context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        table.keyDown(with: enter)
        settle()
        XCTAssertNil(store.renamingHosts, "Return in the list must not start renaming")
    }

    func testEditorLayout_keepsTextAboveFooter_inLightDarkAndCompactWindows() throws {
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { NSApp.setActivationPolicy(previousPolicy) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("gasmask-ui-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let files = try ["Development", "Production", "QA", "Sandbox", "Staging", "Work"].map { name in
            let path = directory.appendingPathComponent("\(name).hst")
            let content = (0..<100).map { "127.0.0.1 \(name.lowercased())-\($0).example.test" }.joined(separator: "\n")
            try content.write(to: path, atomically: true, encoding: .utf8)
            return try XCTUnwrap(Hosts(path: path.path))
        }
        let combinedPath = directory.appendingPathComponent("Combined.hst")
        try "".write(to: combinedPath, atomically: true, encoding: .utf8)
        let combined = try XCTUnwrap(CombinedHosts(path: combinedPath.path, allHostsFiles: files))
        combined.setHostsFiles(Array(files.prefix(5)))
        combined.setSaved(true)
        combined.setActive(true)

        let localGroup = try XCTUnwrap(HostsGroup(name: "LOCAL"))
        localGroup.children = files
        let combinedGroup = try XCTUnwrap(HostsGroup(name: "COMBINED"))
        combinedGroup.children = [combined]
        let store = HostsDataStore()
        store.hostsGroups = [localGroup, combinedGroup]
        store.filesCount = files.count + 1
        store.canRemoveFiles = true
        store.selectedHosts = combined

        let preview = EditorWindowPresenter.makeEditorWindow(store: store)
        defer { preview.orderOut(nil) }
        let output = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/ui-qa")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        func descendants(_ view: NSView) -> [NSView] {
            [view] + view.subviews.flatMap(descendants)
        }

        for (name, appearance, size) in [
            ("combined-light", NSAppearance.Name.aqua, NSSize(width: 1100, height: 700)),
            ("combined-dark", NSAppearance.Name.darkAqua, NSSize(width: 1100, height: 700)),
            ("combined-compact", NSAppearance.Name.aqua, NSSize(width: 620, height: 480))
        ] {
            preview.appearance = NSAppearance(named: appearance)
            preview.setContentSize(size)
            preview.center()
            preview.makeKeyAndOrderFront(nil)
            if #available(macOS 14.0, *) { NSApp.activate() }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.4))
            let content = try XCTUnwrap(preview.contentView)
            content.layoutSubtreeIfNeeded()
            let scroll = try XCTUnwrap(descendants(content).compactMap { $0 as? NSScrollView }
                .first { $0.documentView is HostsTextView })
            let textView = try XCTUnwrap(scroll.documentView as? HostsTextView)
            if let container = textView.textContainer {
                textView.layoutManager?.ensureLayout(for: container)
            }
            textView.scrollRangeToVisible(NSRange(location: (textView.string as NSString).length, length: 0))
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
            let rect = scroll.convert(scroll.bounds, to: content)
            let footerHeight = content.isFlipped
                ? content.bounds.maxY - rect.maxY
                : rect.minY - content.bounds.minY
            let table = try XCTUnwrap(descendants(content).compactMap { $0 as? CombinedFilesTableView }.first)
            let listRect = table.enclosingScrollView!.convert(table.enclosingScrollView!.bounds, to: content)
            XCTAssertGreaterThanOrEqual(listRect.minX, rect.maxX, "Composition must sit to the right of the editor in \(name)")
            XCTAssertLessThanOrEqual(listRect.width, 240, "Right sidebar stays compact in \(name)")
            XCTAssertEqual(table.rowHeight, 22)
            XCTAssertEqual(table.numberOfRows, combined.hostsFiles()?.count ?? 0)
            XCTAssertGreaterThanOrEqual(footerHeight, 24, "Editor must reserve the opaque footer in \(name)")
            XCTAssertGreaterThan(scroll.contentView.bounds.minY, 0, "Long Combined content must scroll to its end in \(name)")

            let frameView = content.superview ?? content
            let bitmap = try XCTUnwrap(frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds))
            frameView.cacheDisplay(in: frameView.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: output.appendingPathComponent("\(name).png"))
            let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
            print("UI QA \(name): footer \(footerHeight)pt, toolbar \(preview.toolbar?.items.map { $0.itemIdentifier.rawValue } ?? []), display \(preview.toolbar?.displayMode.rawValue ?? 0)")

            // A temporary marker allows native UI inspection against these synthetic
            // fixtures. Normal test runs continue immediately; preview pauses time out.
            let hold = output.appendingPathComponent("hold-preview")
            let holdSeconds = min(Double((try? String(contentsOf: hold, encoding: .utf8)) ?? "") ?? 60, 180)
            let deadline = Date(timeIntervalSinceNow: holdSeconds)
            if name == "combined-light" {
                while FileManager.default.fileExists(atPath: hold.path), Date() < deadline {
                    // XCTest holds the main thread here. Dispatch real AppKit
                    // events as well as run-loop sources so native mouse drags
                    // from the inspection tool reach the fixture window.
                    while let event = NSApp.nextEvent(matching: .any, until: Date(), inMode: .default, dequeue: true) {
                        NSApp.sendEvent(event)
                    }
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
                }
            }
        }
        let content = try XCTUnwrap(preview.contentView)
        let table = try XCTUnwrap(descendants(content).compactMap { $0 as? CombinedFilesTableView }.first)
        store.remove(files[0], from: combined)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(table.numberOfRows, (combined.hostsFiles() as? [Hosts])?.count)
        store.add(files[5], to: combined)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(table.numberOfRows, (combined.hostsFiles() as? [Hosts])?.count)
        store.move(files[5], in: combined, toInsertionIndex: 0)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        let firstCell = try XCTUnwrap(table.view(atColumn: 0, row: 0, makeIfNecessary: true))
        XCTAssertTrue(descendants(firstCell).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "Work" },
                      "Native table must refresh after a same-count reorder")
    }

    func testToolbarDisplayMode_survivesFocusRefreshAndWindowRecreation() throws {
        let suite = "GasMaskToolbarTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HostsDataStore()
        let preview = EditorWindowPresenter.makeEditorWindow(store: store, defaults: defaults)
        preview.makeKeyAndOrderFront(nil)
        defer { preview.orderOut(nil) }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        let toolbar = try XCTUnwrap(preview.toolbar)
        XCTAssertEqual(toolbar.displayMode, .iconAndLabel)
        toolbar.displayMode = .iconOnly
        XCTAssertEqual(defaults.integer(forKey: EditorWindowPresenter.toolbarDisplayModeKey), Int(NSToolbar.DisplayMode.iconOnly.rawValue))
        for _ in 0..<3 {
            preview.delegate?.windowDidBecomeMain?(Notification(name: NSWindow.didBecomeMainNotification, object: preview))
            store.isBusy.toggle()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
            XCTAssertEqual(preview.toolbar?.displayMode, .iconOnly)
        }
        preview.orderOut(nil)
        // A new defaults instance and window exercise the next-launch path.
        let reopenedDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let reopened = EditorWindowPresenter.makeEditorWindow(store: HostsDataStore(), defaults: reopenedDefaults)
        reopened.makeKeyAndOrderFront(nil)
        defer { reopened.orderOut(nil) }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        XCTAssertEqual(reopened.toolbar?.displayMode, .iconOnly)
        reopened.toolbar?.displayMode = .iconAndLabel
        reopened.delegate?.windowDidBecomeMain?(Notification(name: NSWindow.didBecomeMainNotification, object: reopened))
        XCTAssertEqual(reopened.toolbar?.displayMode, .iconAndLabel)
        XCTAssertEqual(defaults.integer(forKey: EditorWindowPresenter.toolbarDisplayModeKey), Int(NSToolbar.DisplayMode.iconAndLabel.rawValue))
    }

    func testWindowShouldClose_returnsTrue() {
        let result = window.delegate?.windowShouldClose?(window) ?? false
        XCTAssertTrue(result)
    }
}
