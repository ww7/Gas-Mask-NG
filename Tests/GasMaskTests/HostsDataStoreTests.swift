import XCTest
@testable import Gas_Mask

final class HostsDataStoreTests: XCTestCase {

    func testRemoteRefresh_targetsContextFileAndRecoversAfterFailure() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("gasmask-refresh-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files = try ["First", "Second"].map { name -> RemoteHosts in
            let path = directory.appendingPathComponent("\(name).hst")
            try "127.0.0.1 old.example.test".write(to: path, atomically: true, encoding: .utf8)
            let file = try XCTUnwrap(RemoteHosts(path: path.path))
            file.url = URL(string: "https://gasmask-refresh.example.test/\(name)")!
            return file
        }
        let main = try XCTUnwrap(HostsMainController.defaultInstance())
        let network = try XCTUnwrap(Network.defaultInstance())
        let previousOnline = network.online
        let previousControllers = main.value(forKey: "controllers")
        let previousContent = main.content
        let previousProperties = Preferences.remoteHostsFilesProperties()
        let controller = RemoteHostsController()
        controller.hostsFiles.addObjects(from: files)
        let group = try XCTUnwrap(controller.hostsGroup())
        group.children = files
        main.setValue([LocalHostsController(), controller, CombinedHostsController()], forKey: "controllers")
        main.content = [group]
        network.online = true
        RefreshFixtureProtocol.fail = false
        RefreshFixtureProtocol.paths = []
        URLProtocol.registerClass(RefreshFixtureProtocol.self)
        defer {
            URLProtocol.unregisterClass(RefreshFixtureProtocol.self)
            // The manager owns a periodic timer after completion; stop it before
            // restoring the fixture controller's surrounding test state.
            let manager = controller.value(forKey: "manager") as? NSObject
            (manager?.value(forKey: "timer") as? Timer)?.invalidate()
            main.setValue(previousControllers, forKey: "controllers")
            main.content = previousContent
            Preferences.setRemoteHostsFilesProperties(previousProperties)
            network.online = previousOnline
        }
        let store = HostsDataStore()
        store.selectedHosts = files[0]
        let original = try Data(contentsOf: URL(fileURLWithPath: files[0].path))
        func waitForCompletion() {
            let deadline = Date(timeIntervalSinceNow: 5)
            repeat { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02)) }
            while store.isBusy && Date() < deadline
            XCTAssertFalse(store.isBusy)
            XCTAssertFalse(group.synchronizing())
            XCTAssertTrue(files[1].enabled())
        }
        store.update(files[1])
        XCTAssertFalse(controller.update(files[1]), "Duplicate request while queued must be rejected")
        waitForCompletion()
        XCTAssertEqual(RefreshFixtureProtocol.paths, ["/Second"])
        XCTAssertTrue(store.selectedHosts === files[0], "Context action must not depend on or change selection")
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: files[0].path)), original)
        XCTAssertEqual(files[1].contents(), RefreshFixtureProtocol.body)
        XCTAssertEqual(try String(contentsOfFile: files[1].path, encoding: .utf8), RefreshFixtureProtocol.body)
        XCTAssertTrue(files[1].saved())

        // Unchanged content and an error both end the busy state; a failed
        // refresh must not leave the group permanently synchronizing.
        store.update(files[1]); waitForCompletion()
        RefreshFixtureProtocol.fail = true
        store.update(files[1]); waitForCompletion()
        XCTAssertNotNil(files[1].error())
        XCTAssertEqual(files[1].contents(), RefreshFixtureProtocol.body)
        RefreshFixtureProtocol.fail = false
        store.update(files[1]); waitForCompletion()
        XCTAssertNil(files[1].error(), "Successful unchanged response clears the previous download error")
        XCTAssertEqual(RefreshFixtureProtocol.paths, Array(repeating: "/Second", count: 4))
        network.online = false
        XCTAssertFalse(controller.update(files[1]))
        network.online = true
        let foreign = try XCTUnwrap(RemoteHosts(path: directory.appendingPathComponent("Foreign.hst").path))
        foreign.url = files[1].url
        XCTAssertFalse(controller.update(foreign))
    }

    func testProfileSearchAndActiveStatistics_excludeCommentsAndCombinedDuplicates() throws {
        let contents = "# 1.2.3.4 hidden.test\r\n 127.0.0.1 One.test alias.test # ignored.test\n::1 one.TEST two.test.\ninvalid invalid.test\n\n"
        XCTAssertEqual(HostsStatistics.uniqueHostCount(contents), 3)
        XCTAssertEqual(HostsStatistics.uniqueHostCount("# only comments\n"), 0)
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("gasmask-search-\(UUID().uuidString).hst")
        try contents.write(to: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: path) }
        let local = try XCTUnwrap(Hosts(path: path.path))
        let combined = try XCTUnwrap(CombinedHosts(path: path.path + ".combined", allHostsFiles: [local]))
        combined.setHostsFiles([local])
        let group = try XCTUnwrap(HostsGroup(name: "LOCAL"))
        group.children = [local, combined]
        let store = HostsDataStore()
        store.hostsGroups = [group]
        XCTAssertEqual(store.searchDocuments.count, 1)
        let matches = ProfileSearchIndex.matches("ONE.test", documents: store.searchDocuments)
        XCTAssertEqual(matches.map(\.line), [2, 3])
        for match in matches {
            XCTAssertEqual((contents as NSString).substring(with: match.range).lowercased(), "one.test")
        }
        let unicode = ProfileSearchDocument(path: "fixture", name: "Unicode", remote: true, contents: "# 😀\r\n::1 café.test\r\n")
        let match = try XCTUnwrap(ProfileSearchIndex.matches("cafe", documents: [unicode]).first)
        XCTAssertEqual(match.line, 2)
        XCTAssertEqual((unicode.contents as NSString).substring(with: match.range), "café")
        XCTAssertTrue(ProfileSearchIndex.matches("", documents: [unicode]).isEmpty)
        let big = ProfileSearchDocument(path: "fixture", name: "Big", remote: false,
            contents: Array(repeating: "127.0.0.1 found.test", count: 1000).joined(separator: "\n"))
        XCTAssertEqual(ProfileSearchIndex.matches("found", documents: [big]).count, ProfileSearchIndex.resultLimit)
    }

    // MARK: - Notification Name Constants

    /// Verify Swift notification names match the ObjC #define values from Gas_Mask_Prefix.pch
    func testNotificationNames_matchObjCDefines() {
        XCTAssertEqual(NSNotification.Name.hostsFileCreated.rawValue, "HostsFileCreatedNotification")
        XCTAssertEqual(NSNotification.Name.hostsFileRemoved.rawValue, "HostsFileRemovedNotification")
        XCTAssertEqual(NSNotification.Name.hostsFileRenamed.rawValue, "HostsFileRenamedNotification")
        XCTAssertEqual(NSNotification.Name.hostsFileSaved.rawValue, "HostsFileSavedNotification")
        XCTAssertEqual(NSNotification.Name.hostsNodeNeedsUpdate.rawValue, "HostsNodeNeedsUpdateNotification")
        XCTAssertEqual(NSNotification.Name.hostsFileShouldBeRenamed.rawValue, "HostsFileShouldBeRenamedNotification")
        XCTAssertEqual(NSNotification.Name.hostsFileShouldBeSelected.rawValue, "HostsFileShouldBeSelectedNotification")
        XCTAssertEqual(NSNotification.Name.synchronizingStatusChanged.rawValue, "SynchronizingStatusChangedNotification")
        XCTAssertEqual(NSNotification.Name.allHostsFilesLoadedFromDisk.rawValue, "AllHostsFilesLoadedFromDiskNotification")
    }

    // MARK: - Instance Creation

    func testInit_returnsDistinctInstances() {
        let a = HostsDataStore()
        let b = HostsDataStore()
        XCTAssertFalse(a === b)
    }

    // MARK: - Notification Response

    func testRenameNotification_setsRenamingHosts() {
        let store = HostsDataStore()

        let hosts = Hosts(path: "/tmp/test.hst")!
        store.renamingHosts = nil

        NotificationCenter.default.post(name: .hostsFileShouldBeRenamed, object: hosts)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertTrue(store.renamingHosts === hosts)
    }

    func testSelectNotification_updatesSelectedHosts() {
        let store = HostsDataStore()

        let hosts = Hosts(path: "/tmp/test.hst")!
        store.selectedHosts = nil

        NotificationCenter.default.post(name: .hostsFileShouldBeSelected, object: hosts)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertTrue(store.selectedHosts === hosts)
    }

    // MARK: - Busy State

    func testBusyNotification_setsIsBusy() {
        let store = HostsDataStore()
        XCTAssertFalse(store.isBusy, "precondition")

        NotificationCenter.default.post(name: .threadBusy, object: nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertTrue(store.isBusy)
    }

    func testNotBusyNotification_clearsIsBusy() {
        let store = HostsDataStore()

        NotificationCenter.default.post(name: .threadBusy, object: nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertTrue(store.isBusy, "precondition")

        NotificationCenter.default.post(name: .threadNotBusy, object: nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertFalse(store.isBusy)
    }

    // MARK: - Row Refresh Token

    func testRowRefreshToken_incrementsOnHostsNodeNeedsUpdate() {
        let store = HostsDataStore()
        let before = store.rowRefreshToken

        NotificationCenter.default.post(name: .hostsNodeNeedsUpdate, object: nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertEqual(store.rowRefreshToken, before &+ 1)
    }

    func testRowRefreshToken_incrementsOnHostsFileSaved() {
        let store = HostsDataStore()
        let before = store.rowRefreshToken

        NotificationCenter.default.post(name: .hostsFileSaved, object: nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertEqual(store.rowRefreshToken, before &+ 1)
    }

    func testRowRefreshToken_incrementsOnSynchronizingStatusChanged() {
        let store = HostsDataStore()
        let before = store.rowRefreshToken

        NotificationCenter.default.post(name: .synchronizingStatusChanged, object: nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertEqual(store.rowRefreshToken, before &+ 1)
    }

    func testRowRefreshToken_doesNotChangeOnUnrelatedNotification() {
        let store = HostsDataStore()
        let before = store.rowRefreshToken

        NotificationCenter.default.post(name: .hostsFileCreated, object: nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertEqual(store.rowRefreshToken, before)
    }
    func testCombinedComposition_addRemoveReorderAndReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("GasMaskCombined-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files = try ["Alpha", "Beta", "Gamma"].map { name in
            let path = directory.appendingPathComponent("\(name).hst")
            try "127.0.0.1 \(name.lowercased()).example.test".write(to: path, atomically: true, encoding: .utf8)
            return try XCTUnwrap(Hosts(path: path.path))
        }
        let path = directory.appendingPathComponent("Combined.hst")
        try "".write(to: path, atomically: true, encoding: .utf8)
        let combined = try XCTUnwrap(CombinedHosts(path: path.path, allHostsFiles: files))
        let local = try XCTUnwrap(HostsGroup(name: "LOCAL"))
        local.children = files
        let group = try XCTUnwrap(HostsGroup(name: "COMBINED"))
        group.children = [combined]
        let store = HostsDataStore()
        store.hostsGroups = [local, group]
        XCTAssertFalse(combined.editable, "Generated text remains read-only; composition is editable")
        XCTAssertEqual(store.combinableHosts.count, 3)
        for file in files { store.add(file, to: combined) }
        XCTAssertFalse(combined.saved())
        store.move(files[2], in: combined, by: -1)
        store.remove(files[0], from: combined)
        store.add(files[0], to: combined)
        XCTAssertEqual((combined.hostsFiles() as? [Hosts])?.map { $0.name() }, ["Gamma", "Beta", "Alpha"])
        let contents = try XCTUnwrap(combined.contents())
        let gamma = try XCTUnwrap(contents.range(of: "gamma.example.test"))
        let beta = try XCTUnwrap(contents.range(of: "beta.example.test"))
        let alpha = try XCTUnwrap(contents.range(of: "alpha.example.test"))
        XCTAssertLessThan(gamma.lowerBound, beta.lowerBound)
        XCTAssertLessThan(beta.lowerBound, alpha.lowerBound)
        combined.save()
        XCTAssertTrue(combined.saved())
        let reopened = try XCTUnwrap(CombinedHosts(path: path.path, allHostsFiles: files))
        XCTAssertEqual((reopened.hostsFiles() as? [Hosts])?.map { $0.name() }, ["Gamma", "Beta", "Alpha"])
        XCTAssertEqual(reopened.contents(), contents)
        // No duplicates, nested Combined files, or moves beyond either end.
        store.add(files[0], to: combined)
        store.add(combined, to: combined)
        store.move(files[2], in: combined, by: -1)
        store.move(files[0], in: combined, by: 1)
        XCTAssertTrue(combined.saved(), "Rejected actions must not dirty the composition")
        for file in files { store.remove(file, from: combined) }
        XCTAssertEqual(combined.hostsFiles()?.count, 0)
        XCTAssertEqual(combined.contents(), "")
        combined.save()
        let empty = try XCTUnwrap(CombinedHosts(path: path.path, allHostsFiles: files))
        XCTAssertEqual(empty.hostsFiles()?.count, 0)
    }

    func testCombinedDropInsertion_boundariesAndSavedOrder() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("GasMaskDrop-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files = try ["Alpha", "Beta", "Gamma", "Delta"].map { name in
            let path = directory.appendingPathComponent("\(name).hst")
            try "127.0.0.1 \(name.lowercased()).example.test".write(to: path, atomically: true, encoding: .utf8)
            return try XCTUnwrap(Hosts(path: path.path))
        }
        let path = directory.appendingPathComponent("Combined.hst")
        try "".write(to: path, atomically: true, encoding: .utf8)
        let combined = try XCTUnwrap(CombinedHosts(path: path.path, allHostsFiles: files))
        combined.setHostsFiles(files)
        let store = HostsDataStore()
        XCTAssertTrue(store.move(files[0], in: combined, toInsertionIndex: 4))
        XCTAssertEqual((combined.hostsFiles() as? [Hosts])?.map { $0.name() }, ["Beta", "Gamma", "Delta", "Alpha"])
        XCTAssertTrue(store.move(files[0], in: combined, toInsertionIndex: 0))
        XCTAssertEqual((combined.hostsFiles() as? [Hosts])?.map { $0.name() }, ["Alpha", "Beta", "Gamma", "Delta"])
        XCTAssertTrue(store.move(files[2], in: combined, toInsertionIndex: 1))
        XCTAssertFalse(combined.saved())
        combined.save()
        // Dropping on either boundary of the same row and invalid/external rows
        // must not dirty a saved composition or lose/duplicate any file.
        XCTAssertFalse(store.move(files[0], in: combined, toInsertionIndex: 0))
        XCTAssertFalse(store.move(files[0], in: combined, toInsertionIndex: 1))
        XCTAssertFalse(store.move(files[0], in: combined, toInsertionIndex: -1))
        XCTAssertFalse(store.move(files[0], in: combined, toInsertionIndex: 5))
        let foreign = try XCTUnwrap(Hosts(path: directory.appendingPathComponent("foreign.hst").path))
        XCTAssertFalse(store.move(foreign, in: combined, toInsertionIndex: 1))
        XCTAssertTrue(combined.saved())
        let reopened = try XCTUnwrap(CombinedHosts(path: path.path, allHostsFiles: files))
        XCTAssertEqual((reopened.hostsFiles() as? [Hosts])?.map { $0.name() }, ["Alpha", "Gamma", "Beta", "Delta"])
        XCTAssertEqual(reopened.contents(), combined.contents())
    }

}

// Intercept only this test's reserved host: no live downloads or system hosts.
private final class RefreshFixtureProtocol: URLProtocol {
    static var paths: [String] = []
    static var fail = false
    static let body = "127.0.0.1 updated.example.test"
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "gasmask-refresh.example.test"
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        DispatchQueue.main.async {
            Self.paths.append(self.request.url!.path)
            if Self.fail {
                self.client?.urlProtocol(self, didFailWithError: NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost))
            } else {
                let response = HTTPURLResponse(url: self.request.url!, statusCode: 200, httpVersion: nil,
                    headerFields: ["Content-Type": "text/plain"])!
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: Data(Self.body.utf8))
                self.client?.urlProtocolDidFinishLoading(self)
            }
        }
    }
    override func stopLoading() {}
}
