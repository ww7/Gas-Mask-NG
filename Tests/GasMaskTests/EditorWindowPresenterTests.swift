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
        combined.setActive(true)
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
        XCTAssertFalse(table.floatsGroupRows, "Sidebar labels must not draw a floating header rule")
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
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { NSApp.setActivationPolicy(previousPolicy) }
        if #available(macOS 14.0, *) { NSApp.activate() }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("gasmask-rename-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("New Profile.hst")
        try "127.0.0.1 fixture.example.test".write(to: path, atomically: true, encoding: .utf8)
        let hosts = try XCTUnwrap(Hosts(path: path.path))
        let middlePath = directory.appendingPathComponent("Middle Profile.hst")
        try "127.0.0.1 middle.example.test".write(to: middlePath, atomically: true, encoding: .utf8)
        let middle = try XCTUnwrap(Hosts(path: middlePath.path))
        let main = try XCTUnwrap(HostsMainController.defaultInstance())
        let previousControllers = main.value(forKey: "controllers")
        let previousContent = main.content
        defer {
            main.setValue(previousControllers, forKey: "controllers")
            main.content = previousContent
        }
        let controller = LocalHostsController()
        controller.hostsFiles.add(hosts)
        controller.hostsFiles.add(middle)
        let group = try XCTUnwrap(controller.hostsGroup())
        group.children = [hosts, middle]
        main.setValue([controller, RemoteHostsController(), CombinedHostsController()], forKey: "controllers")
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
        let table = try XCTUnwrap(descendants(content).compactMap { $0 as? NSTableView }.first)
        XCTAssertEqual(table.selectedRow, 2, "New Profile sorts after Middle Profile")
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
        XCTAssertEqual(table.selectedRow, 1, "Renamed file must immediately move before Middle Profile")
        XCTAssertTrue(preview.firstResponder === editor)
        XCTAssertEqual(store.editorFocusRequest, 0, "Blur must not redirect the clicked focus target")
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(hosts.path)))

        let submitted = try beginRename("Submit Renamed")
        submitted.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        settle()
        XCTAssertNil(store.renamingHosts)
        XCTAssertEqual(hosts.name(), "Submit Renamed")
        XCTAssertEqual(table.selectedRow, 2, "Renamed file must immediately move after Middle Profile")
        XCTAssertTrue(preview.firstResponder === editor)
        XCTAssertEqual(store.editorFocusRequest, 1, "Return must finish only once")

        let cancelled = try beginRename("Discard This Name")
        cancelled.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        settle()
        XCTAssertNil(store.renamingHosts)
        XCTAssertEqual(hosts.name(), "Submit Renamed")
        XCTAssertEqual(store.editorFocusRequest, 1)

        XCTAssertTrue(preview.makeFirstResponder(table))
        let enter = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: preview.windowNumber,
            context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        table.keyDown(with: enter)
        settle()
        XCTAssertNil(store.renamingHosts, "Return in the list must not start renaming")

        // Native View menu key equivalents zoom only the document presentation.
        let defaults = UserDefaults.standard
        let previousFontSize = defaults.object(forKey: "editorFontSize")
        defer {
            if let previousFontSize { defaults.set(previousFontSize, forKey: "editorFontSize") }
            else { defaults.removeObject(forKey: "editorFontSize") }
        }
        defaults.set(12.0, forKey: "editorFontSize")
        settle()
        XCTAssertTrue(preview.makeFirstResponder(editor))
        let viewMenu = try XCTUnwrap(NSApp.mainMenu?.item(withTitle: "View")?.submenu)
        let beforeText = editor.string
        let beforeSaved = hosts.saved()
        let beforeBytes = try Data(contentsOf: URL(fileURLWithPath: try XCTUnwrap(hosts.path)))
        func command(_ character: String, size: CGFloat) throws {
            viewMenu.update()
            let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: .command, timestamp: 0, windowNumber: preview.windowNumber,
                context: nil, characters: character, charactersIgnoringModifiers: character,
                isARepeat: false, keyCode: 0))
            XCTAssertTrue(viewMenu.item(withTitle: "Increase Text Size")?.target as AnyObject? === ApplicationController.defaultInstance())
            XCTAssertTrue(viewMenu.performKeyEquivalent(with: event))
            XCTAssertEqual(defaults.double(forKey: "editorFontSize"), Double(size), "Saved size")
            settle()
            XCTAssertEqual(editor.font?.pointSize, size, "Size after SwiftUI update")
        }
        try command("+", size: 13)
        try command("-", size: 12)
        XCTAssertTrue(preview.makeFirstResponder(table))
        try command("=", size: 13)
        try command("0", size: 12)
        XCTAssertEqual(editor.string, beforeText)
        XCTAssertEqual(hosts.saved(), beforeSaved, "Zoom must not dirty the profile")
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: try XCTUnwrap(hosts.path))), beforeBytes)
        XCTAssertEqual((editor.typingAttributes[.font] as? NSFont)?.pointSize, 12)
        let update = try XCTUnwrap(NSApp.mainMenu?.item(withTitle: "File")?.submenu?.item(withTitle: "Update Remote Files"))
        XCTAssertEqual(update.action, #selector(ApplicationController.updateAndSynchronize(_:)))
        XCTAssertNotNil(update.image)
        XCTAssertFalse(store.canUpdateRemoteFiles)

    }

    func testEditorLayout_keepsTextAboveFooter_inLightDarkAndCompactWindows() throws {
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { NSApp.setActivationPolicy(previousPolicy) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("gasmask-ui-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let files = try ["Development", "Production", "QA", "Sandbox", "Staging", "Work"].map { name -> Hosts in
            let path = directory.appendingPathComponent("\(name).hst")
            let content = (0..<100).map { "127.0.0.1 \(name.lowercased())-\($0).example.test" }.joined(separator: "\n")
            let conflictLine = name == "Development" ? "\n127.0.0.1 conflict.example.test" : name == "Production" ? "\n127.0.0.2 conflict.example.test" : ""
            try (content + conflictLine).write(to: path, atomically: true, encoding: .utf8)
            if name == "Production" {
                let remote = try XCTUnwrap(RemoteHosts(path: path.path))
                remote.updated = Date(timeIntervalSince1970: 1792104300)
                return remote
            }
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
            ("combined-compact", NSAppearance.Name.aqua, NSSize(width: 620, height: 480)),
            ("combined-icons", NSAppearance.Name.aqua, NSSize(width: 1100, height: 700))
        ] {
            preview.appearance = NSAppearance(named: appearance)
            preview.setContentSize(size)
            preview.center()
            preview.makeKeyAndOrderFront(nil)
            if #available(macOS 14.0, *) { NSApp.activate() }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.4))
            preview.toolbar?.displayMode = name == "combined-icons" ? .iconOnly : .iconAndLabel
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
            if name == "combined-icons" {
                if #available(macOS 26.0, *) {
                    let spaces = (preview.toolbar?.items ?? []).filter { $0.itemIdentifier == .space }
                    XCTAssertEqual(spaces.count, 3)
                    XCTAssertTrue(spaces.allSatisfy { $0.isNavigational }, "Spaces must stay among the leading actions in icon-only mode")
                }
            }
            let content = try XCTUnwrap(preview.contentView)
            content.layoutSubtreeIfNeeded()
            let scroll = try XCTUnwrap(descendants(content).compactMap { $0 as? NSScrollView }
                .first { $0.documentView is HostsTextView })
            let textView = try XCTUnwrap(scroll.documentView as? HostsTextView)
            XCTAssertEqual(textView.textContainerInset, NSSize(width: 8, height: 8))
            XCTAssertEqual(textView.textContainer?.lineFragmentPadding, 0)
            XCTAssertEqual(textView.font?.fontName,
                NSFont.monospacedSystemFont(ofSize: textView.font?.pointSize ?? 12, weight: .medium).fontName)
            let sidebarTable = try XCTUnwrap(descendants(content).compactMap { $0 as? NSTableView }
                .first { !($0 is CombinedFilesTableView) })
            XCTAssertFalse(sidebarTable.floatsGroupRows)
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

            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
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
        store.selectedHosts = files[1]
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        let remoteHold = output.appendingPathComponent("hold-remote-update")
        let remoteDeadline = Date(timeIntervalSinceNow: 120)
        while FileManager.default.fileExists(atPath: remoteHold.path), Date() < remoteDeadline {
            while let event = NSApp.nextEvent(matching: .any, until: Date(), inMode: .default, dequeue: true) { NSApp.sendEvent(event) }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
    }

    func testFindCommentAndSearchNavigation_useNativeEditorPipeline() throws {
        let previousPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        defer { NSApp.setActivationPolicy(previousPolicy) }
        if #available(macOS 14.0, *) { NSApp.activate() }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("gasmask-editing-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = "  127.0.0.1 first.test\r\n\t::1 second.test\r\n\r\n# already commented\r\n"
        let path = directory.appendingPathComponent("Editable.hst")
        try original.write(to: path, atomically: true, encoding: .utf8)
        let hosts = try XCTUnwrap(Hosts(path: path.path))
        let remotePath = directory.appendingPathComponent("Remote.hst")
        try "127.0.0.2 needle.test".write(to: remotePath, atomically: true, encoding: .utf8)
        let remote = try XCTUnwrap(RemoteHosts(path: remotePath.path))
        let group = try XCTUnwrap(HostsGroup(name: "LOCAL")); group.children = [hosts, remote]
        let store = HostsDataStore(); store.hostsGroups = [group]; store.selectedHosts = hosts
        let preview = EditorWindowPresenter.makeEditorWindow(store: store)
        preview.makeKeyAndOrderFront(nil)
        defer { preview.orderOut(nil) }
        func settle() { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.25)) }
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        settle()
        let content = try XCTUnwrap(preview.contentView)
        let editor = try XCTUnwrap(descendants(content).compactMap { $0 as? HostsTextView }.first)
        XCTAssertTrue(editor.usesFindBar)
        let find = NSMenuItem(); find.tag = 1
        EditorWindowPresenter.findInEditor(find)
        settle()
        XCTAssertTrue(editor.enclosingScrollView?.isFindBarVisible == true)
        let pasteboard = NSPasteboard(name: .find)
        let savedFindItems = (pasteboard.pasteboardItems ?? []).map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem()
            for type in item.types { if let data = item.data(forType: type) { copy.setData(data, forType: type) } }
            return copy
        }
        defer { pasteboard.clearContents(); pasteboard.writeObjects(savedFindItems) }
        let firstMatch = (editor.string as NSString).range(of: "first.test")
        editor.setSelectedRange(firstMatch)
        let useSelection = NSMenuItem(); useSelection.tag = 7
        EditorWindowPresenter.findInEditor(useSelection)
        editor.setSelectedRange(NSRange(location: 0, length: 0))
        let next = NSMenuItem(); next.tag = 2
        EditorWindowPresenter.findInEditor(next); settle()
        XCTAssertEqual(editor.selectedRange(), firstMatch, "Native Find Next must select the matching text")
        let hide = NSMenuItem(); hide.tag = 11
        editor.performTextFinderAction(hide)
        preview.makeFirstResponder(editor)
        editor.setSelectedRange(NSRange(location: 5, length: 0))
        let commentItem = try XCTUnwrap(NSApp.mainMenu?.item(withTitle: "Edit")?.submenu?.item(withTitle: "Toggle Comment"))
        XCTAssertEqual(commentItem.action, NSSelectorFromString("toggleComment:"))
        XCTAssertEqual(commentItem.keyEquivalent, "/")
        XCTAssertEqual(commentItem.keyEquivalentModifierMask, .command)
        XCTAssertNil(commentItem.target, "Commenting must follow the native responder chain")
        XCTAssertTrue(editor.validateUserInterfaceItem(commentItem))
        XCTAssertTrue(editor.tryToPerform(commentItem.action!, with: commentItem))
        settle()
        XCTAssertTrue(editor.string.hasPrefix("  # 127.0.0.1"))
        XCTAssertEqual(hosts.contents(), editor.string)
        XCTAssertFalse(hosts.saved())
        XCTAssertEqual(try String(contentsOf: path, encoding: .utf8), original, "Commenting must not save or activate")
        editor.undoManager?.undo(); settle()
        XCTAssertEqual(editor.string, original)
        editor.undoManager?.redo(); settle()
        XCTAssertTrue(editor.string.hasPrefix("  # 127.0.0.1"))
        editor.undoManager?.undo(); settle()
        let firstTwo = (original as NSString).range(of: "\r\n\r\n").location + 2
        editor.setSelectedRange(NSRange(location: 0, length: firstTwo))
        editor.toggleComment(nil); settle()
        XCTAssertTrue(editor.string.hasPrefix("  # 127.0.0.1 first.test\r\n\t# ::1 second.test\r\n\r\n"))
        editor.toggleComment(nil); settle()
        XCTAssertEqual(editor.string, original)
        let result = try XCTUnwrap(ProfileSearchIndex.matches("needle", documents: store.searchDocuments).first)
        store.openSearchResult(result); settle()
        XCTAssertTrue(store.selectedHosts === remote)
        XCTAssertEqual(editor.selectedRange(), result.range)
        XCTAssertFalse(editor.validateUserInterfaceItem(commentItem))
        XCTAssertFalse(editor.undoManager?.canUndo == true, "Undo must not leak edits from the previous profile")
        let remoteContents = editor.string
        editor.toggleComment(nil)
        XCTAssertEqual(editor.string, remoteContents)
        XCTAssertEqual(try String(contentsOf: remotePath, encoding: .utf8), remoteContents)
        let findMenu = NSApp.mainMenu?.item(withTitle: "Edit")?.submenu?.item(withTitle: "Find")?.submenu
        XCTAssertEqual(findMenu?.item(withTitle: "Find…")?.action, NSSelectorFromString("findInEditor:"))
        XCTAssertEqual(findMenu?.item(withTitle: "Find in All Profiles…")?.keyEquivalentModifierMask, [.command, .shift])
        func snapshot(_ sheet: NSWindow, name: String) throws {
            let view = try XCTUnwrap(sheet.contentView)
            view.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().appendingPathComponent("build/ui-qa/\(name).png")
            let hold = output.deletingLastPathComponent().appendingPathComponent("hold-\(name)")
            let deadline = Date(timeIntervalSinceNow: 120)
            while FileManager.default.fileExists(atPath: hold.path), Date() < deadline {
                while let event = NSApp.nextEvent(matching: .any, until: Date(), inMode: .default, dequeue: true) { NSApp.sendEvent(event) }
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
            }
            try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: output)
        }
        store.showingHelp = true; settle()
        try snapshot(try XCTUnwrap(preview.attachedSheet), name: "editor-help")
        store.showingHelp = false; settle()
        store.showingGlobalSearch = true; settle()
        let searchSheet = try XCTUnwrap(preview.attachedSheet)
        let field = try XCTUnwrap(searchSheet.firstResponder as? NSTextView)
        field.insertText("needle", replacementRange: field.selectedRange())
        settle()
        try snapshot(searchSheet, name: "global-search")
        field.insertNewline(nil); settle()
        XCTAssertFalse(store.showingGlobalSearch, "Return should open the first global match")
        XCTAssertEqual(editor.selectedRange(), result.range)
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
