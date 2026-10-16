import XCTest
import AppKit
@testable import Gas_Mask

final class SecurityAndIconsTests: XCTestCase {
    func testIndependentIconSettingsAll28CombinationsAndRelaunch() throws {
        let suite = "gasmask-icon-fixtures-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let visibility = NSApp.activationPolicy()
        var applied: NSImage?
        let prefs = IconPreferences(defaults: defaults) { applied = $0 }
        for menu in IconPreferences.symbols {
            for dock in IconPreferences.symbols {
                for palette in IconPreferences.palettes {
                    defaults.set(menu, forKey: "menuBarIcon")
                    defaults.set(dock, forKey: "dockIcon")
                    defaults.set(palette, forKey: "dockPalette")
                    prefs.apply()
                    XCTAssertEqual(prefs.menuSymbol, menu)
                    XCTAssertEqual(prefs.dockSymbol, dock)
                    XCTAssertEqual(prefs.dockPalette, palette)
                    XCTAssertNotNil(applied)
                    XCTAssertTrue(applied === NSImage(named: prefs.dockAssetName))
                    XCTAssertTrue(prefs.menuBarImage.isTemplate)
                    XCTAssertEqual(prefs.menuBarImage.size, NSSize(width: 16, height: 16))
                    let restored = IconPreferences(defaults: try XCTUnwrap(UserDefaults(suiteName: suite))) { _ in }
                    XCTAssertEqual(restored.menuSymbol, menu)
                    XCTAssertEqual(restored.dockAssetName, prefs.dockAssetName)
                }
            }
        }
        XCTAssertEqual(NSApp.activationPolicy(), visibility, "Icon selection must not alter Dock visibility")
        defaults.set("rejected", forKey: "menuBarIcon")
        defaults.set("../../bad", forKey: "dockIcon")
        defaults.set("sunrise", forKey: "dockPalette")
        XCTAssertEqual(prefs.menuSymbol, "mask")
        XCTAssertEqual(prefs.dockAssetName, "Dock_mask_heritage")
    }

    func testMenuTemplatesLightDarkAtBothScalesWithAndWithoutNames() throws {
        let suite = "gasmask-menu-fixtures-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = IconPreferences(defaults: defaults) { _ in }
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("build/icon-qa")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for symbol in IconPreferences.symbols {
            defaults.set(symbol, forKey: "menuBarIcon")
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                for scale in [1, 2] {
                    for title in ["", "Fixture List"] {
                        let item = NSStatusBar.system.statusItem(withLength: title.isEmpty ? 26 : 120)
                        defer { NSStatusBar.system.removeStatusItem(item) }
                        let button = try XCTUnwrap(item.button)
                        button.image = prefs.menuBarImage
                        button.title = title
                        button.imagePosition = title.isEmpty ? .imageOnly : .imageLeft
                        button.appearance = NSAppearance(named: appearance)
                        let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(button.bounds.width) * scale,
                            pixelsHigh: Int(button.bounds.height) * scale, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
                        rep.size = button.bounds.size
                        button.cacheDisplay(in: button.bounds, to: rep)
                        XCTAssertTrue(button.image!.isTemplate)
                        try rep.representation(using: .png, properties: [:])?.write(to: output.appendingPathComponent("\(symbol)-\(appearance.rawValue)-\(scale)x-\(title.isEmpty ? "icon" : "name").png"))
                    }
                }
            }
        }
    }

    func testMenuletRefreshPreservesTitleAndMenuAction() throws {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "work.ww7.gasmask.tests")
        let keys = ["menuBarIcon", "dockIcon", "dockPalette", "showNameInStatusBar"]
        let defaults = UserDefaults.standard
        let old = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, old) { defaults.set(value, forKey: key) }
            IconPreferences.shared.apply()
        }
        let main = try XCTUnwrap(HostsMainController.defaultInstance())
        let previous = main.value(forKey: "controllers")
        let local = LocalHostsController()
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("Fixture List.hst")
        let hosts = try XCTUnwrap(Hosts(path: path.path))
        hosts.setActive(true)
        local.hostsFiles.add(hosts)
        main.setValue([local, RemoteHostsController(), CombinedHostsController()], forKey: "controllers")
        defer { main.setValue(previous, forKey: "controllers") }
        let menulet = Menulet()
        menulet.awakeFromNib()
        let item = try XCTUnwrap(menulet.value(forKey: "statusItem") as? NSStatusItem)
        let button = try XCTUnwrap(item.button)
        for named in [false, true] {
            defaults.set(named, forKey: "showNameInStatusBar")
            NotificationCenter.default.post(name: Notification.Name("activateFileNotification"), object: nil)
            for symbol in IconPreferences.symbols {
                defaults.set(symbol, forKey: "menuBarIcon")
                IconPreferences.shared.apply()
                XCTAssertTrue(button.image?.isTemplate == true)
                XCTAssertEqual(button.title, named ? "Fixture List" : "")
                XCTAssertEqual(button.action, NSSelectorFromString("showMenu:"))
                XCTAssertTrue(button.target === menulet)
                let menu = try XCTUnwrap(ApplicationController.defaultInstance()?.applicationDockMenu(NSApp))
                XCTAssertTrue(menu.items.contains { ($0.representedObject as? Hosts) === hosts })
            }
        }
        XCTAssertFalse(PrivilegedActions.hasAuthorizedSession())
    }

    func testNativeWatcherFollowsAtomicReplacementAndRecreation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("gasmask-watch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("hosts")
        try "initial".write(to: path, atomically: true, encoding: .utf8)
        var changes = 0
        let watcher = SystemHostsWatcher(path: path.path) { changes += 1 }
        defer { watcher.stop() }
        func waitForChange(after value: Int) {
            let deadline = Date(timeIntervalSinceNow: 2)
            while changes == value && Date() < deadline { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02)) }
            XCTAssertGreaterThan(changes, value)
        }
        try "replacement".write(to: path, atomically: true, encoding: .utf8)
        waitForChange(after: 0)
        var before = changes
        try "next inode".write(to: path, atomically: true, encoding: .utf8)
        waitForChange(after: before)
        before = changes
        try FileManager.default.removeItem(at: path)
        waitForChange(after: before)
        before = changes
        try "recreated".write(to: path, atomically: true, encoding: .utf8)
        waitForChange(after: before)
        watcher.stop()
        before = changes
        try "stopped".write(to: path, atomically: true, encoding: .utf8)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(changes, before)
    }

    func testBootstrapParentRejectsGroupWritableAndSymbolicDirectories() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("gasmask-stage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertTrue(PrivilegedActions.trustedDirectory(atPath: directory.path, owner: getuid()))
        try FileManager.default.setAttributes([.posixPermissions: 0o775], ofItemAtPath: directory.path)
        XCTAssertFalse(PrivilegedActions.trustedDirectory(atPath: directory.path, owner: getuid()))
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let link = directory.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: directory)
        XCTAssertFalse(PrivilegedActions.trustedDirectory(atPath: link.path, owner: getuid()))
        XCTAssertFalse(PrivilegedActions.trustedDirectory(atPath: directory.path, owner: getuid()+1))
    }

    func testRemoteURLAndTextValidation() {
        for url in ["http://a.test/hosts", "https://user:pass@a.test/hosts", "https://a.test/hosts#part", "file:///tmp/hosts", "https://a.test:0/hosts", "https://a.test:65536/hosts"] {
            XCTAssertFalse(URLValidator.isValid(url), url)
        }
        for text in ["<html>failure</html>", "127.0.0.1", "hello world", "127.0.0.1 a\0b", "127.0.0.1 <bad>", "127.0.0.1 a..b", "#" + String(repeating: "x", count: 65537), "#" + String(repeating: "ї", count: 40000)] {
            XCTAssertFalse(HostsDownloader.isHostsText(text), text.prefix(40).description)
        }
        XCTAssertTrue(HostsDownloader.isHostsText("# comment\n127.0.0.1 localhost alias.test # note\n::1 ipv6.test\n"))
    }

    func testRemoteStreamingFailuresRetainCacheAndRejectInvalid304() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("gasmask-input-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("Remote.hst")
        let good = "127.0.0.1 retained.test"
        try good.write(to: path, atomically: true, encoding: .utf8)
        let hosts = try XCTUnwrap(RemoteHosts(path: path.path))
        for mode in ["oversized-header", "oversized-stream", "html", "invalid", "empty", "nul", "utf8", "304", "tls"] {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [SecurityInputProtocol.self]
            let downloader = try XCTUnwrap(HostsDownloader(hosts: hosts, url: URL(string: "https://input.example.test/\(mode)")!, sessionConfiguration: config))
            let done = expectation(description: mode)
            let delegate = DownloadProbe { done.fulfill() }
            downloader.setDelegate(delegate)
            downloader.download()
            wait(for: [done], timeout: 8)
            XCTAssertNotNil(downloader.error, mode)
            XCTAssertEqual(try String(contentsOf: path, encoding: .utf8), good)
            XCTAssertEqual(hosts.contents(), good)
            XCTAssertFalse(delegate.success)
        }
    }

    func testRedirectPolicySameOriginAndLimit() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("gasmask-redirect-\(UUID().uuidString)")
        let hosts = try XCTUnwrap(RemoteHosts(path: path.path))
        let source = URL(string: "https://input.example.test/source")!
        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let task = session.dataTask(with: source)
        func allowed(_ url: String, downloader: HostsDownloader) -> URLRequest? {
            var request = URLRequest(url: URL(string: url)!)
            request.setValue("secret", forHTTPHeaderField: "Authorization")
            var result: URLRequest?
            (downloader as URLSessionTaskDelegate).urlSession?(session, task: task,
                willPerformHTTPRedirection: HTTPURLResponse(url: source, statusCode: 302, httpVersion: nil, headerFields: nil)!,
                newRequest: request, completionHandler: { result = $0 })
            return result
        }
        for url in ["http://input.example.test/next", "https://other.test/next", "https://input.example.test:444/next", "https://user:pass@input.example.test/next"] {
            let downloader = try XCTUnwrap(HostsDownloader(hosts: hosts, url: source))
            XCTAssertNil(allowed(url, downloader: downloader))
        }
        let downloader = try XCTUnwrap(HostsDownloader(hosts: hosts, url: source))
        for _ in 0..<5 {
            let accepted = try XCTUnwrap(allowed("https://INPUT.example.test:443/next", downloader: downloader))
            XCTAssertNil(accepted.value(forHTTPHeaderField: "Authorization"))
        }
        XCTAssertNil(allowed("https://input.example.test/next", downloader: downloader))
    }

    func testBackgroundActiveSaveCachesWithoutSystemAuthorization() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("gasmask-pending-\(UUID().uuidString).hst")
        defer { try? FileManager.default.removeItem(at: path) }
        let hosts = try XCTUnwrap(Hosts(path: path.path))
        hosts.setActive(true)
        hosts.setContents("127.0.0.1 pending.test")
        let controller = LocalHostsController()
        controller.save(hosts)
        XCTAssertTrue(hosts.saved())
        XCTAssertTrue(hosts.systemApplyPending)
        XCTAssertEqual(try String(contentsOf: path, encoding: .utf8), "127.0.0.1 pending.test")
        XCTAssertFalse(PrivilegedActions.hasAuthorizedSession())
    }

    func testRootBootstrapRejectsInvalidIdentifiersAndQuotesPaths() async throws {
        try await Task.detached { try Self.verifyBootstrapConstruction() }.value
    }

    private static func verifyBootstrapConstruction() throws {
        var compilationError: NSDictionary?
        let script = try XCTUnwrap(NSAppleScript(source: PrivilegedActions.authorizationScriptSource()))
        XCTAssertTrue(script.compileAndReturnError(&compilationError), "\(String(describing: compilationError))")
        let hash = String(repeating: "a", count: 64), code = String(repeating: "b", count: 40)
        XCTAssertNil(PrivilegedActions.bootstrapCommand(forHelper: "relative", digest: hash, pid: 123, uid: 501, codeHash: code))
        XCTAssertNil(PrivilegedActions.bootstrapCommand(forHelper: "/tmp/helper", digest: "bad", pid: 123, uid: 501, codeHash: code))
        let argument = "/tmp/space ' dollar $(touch BAD) `touch BAD`\nnewline"
        let process = Process(), pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "printf '%s' " + PrivilegedActions.quotedShellArgument(argument)]
        process.standardOutput = pipe
        try process.run()
        let received = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(String(data: received, encoding: .utf8), argument)
    }
}

private final class DownloadProbe: NSObject, HostsDownloaderDelegate {
    let done: () -> Void
    var success = false
    init(_ done: @escaping () -> Void) { self.done = done }
    func hostsDownloadingStarted(_ downloader: HostsDownloader!) {}
    func hostsUp(toDate downloader: HostsDownloader!) { success = true; done() }
    func hostsDownloaded(_ downloader: HostsDownloader!) { success = true; done() }
    func hostsDownloadFailed(_ downloader: HostsDownloader!) { done() }
}

private final class SecurityInputProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "input.example.test" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let mode = request.url!.lastPathComponent
        if mode == "tls" {
            client?.urlProtocol(self, didFailWithError: NSError(domain: NSURLErrorDomain, code: NSURLErrorServerCertificateUntrusted)); return
        }
        let headers = ["Content-Type": mode == "html" ? "text/html" : "text/plain",
            "Content-Length": mode == "oversized-header" ? "33554433" : "-1"]
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: mode == "304" ? 304 : 200, httpVersion: nil, headerFields: headers)!, cacheStoragePolicy: .notAllowed)
        switch mode {
        case "oversized-stream":
            let chunk = Data(repeating: 35, count: 1024 * 1024)
            for _ in 0..<33 { client?.urlProtocol(self, didLoad: chunk) }
        case "utf8": client?.urlProtocol(self, didLoad: Data([0xff]))
        case "empty", "304", "oversized-header": break
        case "nul": client?.urlProtocol(self, didLoad: Data("127.0.0.1 a\0b".utf8))
        default: client?.urlProtocol(self, didLoad: Data("<html>invalid mapping</html>".utf8))
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
