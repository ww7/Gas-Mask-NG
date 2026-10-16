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
        controller.setValue(RefreshFixtureManager(hostsController: controller), forKey: "manager")
        controller.hostsFiles.addObjects(from: files)
        let group = try XCTUnwrap(controller.hostsGroup())
        group.children = files
        main.setValue([LocalHostsController(), controller, CombinedHostsController()], forKey: "controllers")
        main.content = [group]
        network.online = true
        RefreshFixtureProtocol.fail = false
        RefreshFixtureProtocol.statusCode = 200
        RefreshFixtureProtocol.invalidUTF8 = false
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
        XCTAssertNotNil(files[1].updated)
        XCTAssertNil(files[0].updated, "Only the requested file's timestamp changes")
        let earlier = Date(timeIntervalSince1970: 100)
        files[1].updated = earlier

        // Unchanged content and an error both end the busy state; a failed
        // refresh must not leave the group permanently synchronizing.
        store.update(files[1]); waitForCompletion()
        let lastSuccess = try XCTUnwrap(files[1].updated)
        XCTAssertGreaterThan(lastSuccess, earlier, "An unchanged successful check advances the timestamp")
        RefreshFixtureProtocol.fail = true
        store.update(files[1]); waitForCompletion()
        XCTAssertNotNil(files[1].error())
        XCTAssertEqual(files[1].updated, lastSuccess)
        XCTAssertEqual(files[1].contents(), RefreshFixtureProtocol.body)
        RefreshFixtureProtocol.fail = false
        store.update(files[1]); waitForCompletion()
        XCTAssertNil(files[1].error(), "Successful unchanged response clears the previous download error")
        XCTAssertEqual(RefreshFixtureProtocol.paths, Array(repeating: "/Second", count: 4))
        for status in [404, 500] {
            RefreshFixtureProtocol.statusCode = status
            let previous = files[1].updated
            store.update(files[1]); waitForCompletion()
            XCTAssertEqual(files[1].updated, previous, "HTTP errors must not appear successful")
            XCTAssertNotNil(files[1].error())
        }
        RefreshFixtureProtocol.statusCode = 200
        RefreshFixtureProtocol.invalidUTF8 = true
        let beforeInvalid = files[1].updated
        store.update(files[1]); waitForCompletion()
        XCTAssertEqual(files[1].updated, beforeInvalid)
        XCTAssertNotNil(files[1].error())
        RefreshFixtureProtocol.invalidUTF8 = false
        RefreshFixtureProtocol.statusCode = 304
        files[1].updated = earlier
        store.update(files[1]); waitForCompletion()
        XCTAssertGreaterThan(try XCTUnwrap(files[1].updated), earlier)
        XCTAssertNil(files[1].error())
        let retained = files[1].updated
        files[1].updated = nil
        let manager = try XCTUnwrap(controller.value(forKey: "manager") as? NSObject)
        manager.perform(NSSelectorFromString("loadRemoteHostsProperties"))
        XCTAssertEqual(files[1].updated, retained, "Timestamp survives persisted metadata reload")
        RefreshFixtureProtocol.includeLastModified = false
        RefreshFixtureProtocol.statusCode = 200
        store.update(files[1]); waitForCompletion()
        XCTAssertNil(files[1].lastModified, "A fresh 200 without a validator must clear the old one even if text is unchanged")
        let beforeUnconditional304 = files[1].updated
        RefreshFixtureProtocol.statusCode = 304
        store.update(files[1]); waitForCompletion()
        XCTAssertNotNil(files[1].error())
        XCTAssertEqual(files[1].updated, beforeUnconditional304)
        RefreshFixtureProtocol.includeLastModified = true
        RefreshFixtureProtocol.statusCode = 200
        store.update(files[1]); waitForCompletion()
        XCTAssertNotNil(files[1].lastModified)
        XCTAssertNil(files[1].error())
        XCTAssertEqual(RemoteUpdateStatus.summary(nil), "No successful update recorded")
        network.online = false
        XCTAssertFalse(controller.update(files[1]))
        network.online = true
        let foreign = try XCTUnwrap(RemoteHosts(path: directory.appendingPathComponent("Foreign.hst").path))
        foreign.url = files[1].url
        XCTAssertFalse(controller.update(foreign))

        // Exercise the actual one-shot timer entry point, including failure and
        // preference changes. No owner's URL or hosts file is involved.
        let scheduled = try XCTUnwrap(manager.value(forKey: "timer") as? Timer)
        XCTAssertTrue(scheduled.isValid)
        RefreshFixtureProtocol.statusCode = 200
        RefreshFixtureProtocol.paths = []
        scheduled.fire(); waitForCompletion()
        XCTAssertEqual(Set(RefreshFixtureProtocol.paths), ["/First", "/Second"])
        XCTAssertFalse(scheduled.isValid, "A manual fire must retire the previous timer")
        let next = try XCTUnwrap(manager.value(forKey: "timer") as? Timer)
        XCTAssertTrue(next.isValid, "Periodic updates must re-arm after unchanged success")
        RefreshFixtureProtocol.fail = true
        next.fire(); waitForCompletion()
        XCTAssertTrue((manager.value(forKey: "timer") as? Timer)?.isValid == true, "A failed batch must retry on schedule")
        RefreshFixtureProtocol.fail = false
        let beforeIntervalChange = manager.value(forKey: "timer") as? Timer
        manager.perform(NSSelectorFromString("changeTimerInterval"))
        XCTAssertFalse(beforeIntervalChange?.isValid ?? true)
        XCTAssertTrue((manager.value(forKey: "timer") as? Timer)?.isValid == true)
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

    func testSearchRegexAndSnapshot_keepsEditsAndScalesToLargeLists() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("search-\(UUID().uuidString).hst")
        defer { try? FileManager.default.removeItem(at: path) }
        try "127.0.0.1 disk.test".write(to: path, atomically: true, encoding: .utf8)
        let hosts = try XCTUnwrap(Hosts(path: path.path))
        XCTAssertNil(hosts.cachedContents(), "Cold files must not load on the main thread")
        let source = ProfileSearchSource(path: path.path, name: "Disk", remote: true, cachedContents: nil)
        let prepared = ProfileSearchIndex.prepare([source])
        XCTAssertEqual(ProfileSearchIndex.matches("disk", prepared: prepared).count, 1)
        XCTAssertNil(hosts.cachedContents())
        hosts.setContents("# 😀\r\n127.0.0.1 edited.test alias.test\r\n::1 EDITED.test\n")
        let edited = ProfileSearchIndex.prepare([ProfileSearchSource(path: path.path, name: "Edits",
            remote: false, cachedContents: hosts.cachedContents())])
        let regex = try NSRegularExpression(pattern: #"^127\.0\.0\.1\s+(edited\.test)"#, options: .caseInsensitive)
        let matches = ProfileSearchIndex.matches(regex.pattern, prepared: edited, regex: regex)
        XCTAssertEqual(matches.map(\.line), [2])
        XCTAssertEqual(matches.first?.matchedText, "127.0.0.1 edited.test")
        XCTAssertEqual(ProfileSearchIndex.matches("disk", prepared: edited).count, 0)
        XCTAssertThrowsError(try NSRegularExpression(pattern: "["))
        let big = ProfileSearchDocument(path: "fixture", name: "Large", remote: true,
            contents: Array(repeating: "0.0.0.0 example.test", count: 100_000).joined(separator: "\n") + "\n127.0.0.1 final.test")
        let index = PreparedSearchDocument(big)
        let start = Date()
        for query in ["missing", "final", "nomatch"] {
            _ = ProfileSearchIndex.matches(query, prepared: [index])
        }
        let elapsed = Date().timeIntervalSince(start)
        print("SEARCH_BENCHMARK: 100001 lines, three cached literal queries: \(elapsed) seconds")
        XCTAssertLessThan(elapsed, 3, "Cached scans should finish without multi-second lag")
        let final = try XCTUnwrap(ProfileSearchIndex.matches("final", prepared: [index]).first)
        XCTAssertEqual(final.line, 100_001)
        XCTAssertEqual((big.contents as NSString).substring(with: final.range), "final")
    }

    func testCombinedConflicts_compareAddressSetsPerFamilyWithoutChangingSources() {
        let first = ProfileSearchDocument(path: "first", name: "First", remote: false, contents:
            "# 127.0.0.9 ignored.test\r\n\r\n127.0.0.1 MIXED.test alias.test\r\n::1 dual.test\n127.0.0.1 same.test\n2001:db8::1 ipv6.test\n127.0.0.1 multi.test\n127.0.0.2 multi.test\n127.0.0.1 local-only.test\n127.0.0.2 local-only.test\n")
        let second = ProfileSearchDocument(path: "second", name: "Second", remote: true, contents:
            "127.0.0.2 mixed.TEST. alias.test # ignored.test\n127.0.0.1 dual.test same.test\n2001:0db8:0:0:0:0:0:1 ipv6.test\n127.0.0.2 multi.test\n127.0.0.1 multi.test\ninvalid ignored.test\n")
        let documents = [first, second]
        let conflicts = CombinedConflictIndex.conflicts(in: documents)
        XCTAssertEqual(conflicts.map(\.domain), ["alias.test", "local-only.test", "mixed.test", "multi.test"])
        XCTAssertEqual(conflicts[0].sources.map(\.name), ["First", "Second"])
        XCTAssertEqual(conflicts[0].sources.map(\.line), [3, 1], "CRLF and blank lines retain accurate source line numbers")
        XCTAssertEqual(conflicts[0].sources.map(\.address), ["127.0.0.1", "127.0.0.2"])
        XCTAssertTrue(conflicts[0].sources[1].remote)
        XCTAssertEqual(CombinedConflictIndex.conflicts(in: [first]).map(\.domain), ["local-only.test", "multi.test"])
        let repeated = CombinedConflictIndex.conflicts(in: [first, first, second])
        XCTAssertEqual(repeated.map { $0.sources.count }, conflicts.map { $0.sources.count })
        let ipv6 = ProfileSearchDocument(path: "ipv6", name: "IPv6", remote: false,
            contents: "2001:db8::2 ipv6.test\n")
        XCTAssertEqual(CombinedConflictIndex.conflicts(in: [first, ipv6]).map(\.domain), ["ipv6.test", "local-only.test", "multi.test"])
        XCTAssertEqual(CombinedConflictIndex.conflicts(in: [second, first]).map(\.domain), conflicts.map(\.domain))
        XCTAssertEqual(documents, [first, second], "Analysis must not rewrite or reorder sources")
        let changed = ProfileSearchDocument(path: "second", name: "Second", remote: true,
            contents: "127.0.0.1 mixed.test alias.test\n")
        XCTAssertEqual(CombinedConflictIndex.conflicts(in: [first, changed]).map(\.domain), ["local-only.test", "multi.test"])
    }

    func testConflictsWithinRemoteList_normalizeAddressesAndIgnoreIdenticalRepeats() {
        let remote = ProfileSearchDocument(path: "remote-fixture", name: "Remote Fixture", remote: true, contents:
            "127.0.0.1 SAME.test alias.test\n127.0.0.1 same.TEST.\n::1 same.test\n" +
            "127.0.0.2 alias.test # same.test\n# 127.0.0.9 same.test\n" +
            "2001:db8::1 v6.test\n2001:0db8:0:0:0:0:0:1 v6.test\n2001:db8::2 v6.test\n")
        let conflicts = CombinedConflictIndex.conflicts(in: [remote])
        XCTAssertEqual(conflicts.map(\.domain), ["alias.test", "v6.test"])
        XCTAssertEqual(conflicts[0].sources.map(\.line), [1, 4])
        XCTAssertTrue(conflicts.flatMap(\.sources).allSatisfy(\.remote))
        XCTAssertEqual(conflicts[1].sources.map(\.address), ["2001:db8::1", "2001:db8::1", "2001:db8::2"])
        XCTAssertEqual(CombinedConflictIndex.conflicts(in: [remote, remote]).map { $0.sources.count },
                       conflicts.map { $0.sources.count }, "Repeated source references cannot inflate results")
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
    static var statusCode = 200
    static var invalidUTF8 = false
    static var includeLastModified = true
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
                let response = HTTPURLResponse(url: self.request.url!, statusCode: Self.statusCode, httpVersion: nil,
                    headerFields: Self.includeLastModified ? ["Content-Type": "text/plain", "Last-Modified": "Thu, 15 Oct 2026 12:00:00 GMT"] : ["Content-Type": "text/plain"])!
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                if Self.statusCode != 304 { self.client?.urlProtocol(self, didLoad: Self.invalidUTF8 ? Data([0xff]) : Data(Self.body.utf8)) }
                self.client?.urlProtocolDidFinishLoading(self)
            }
        }
    }
    override func stopLoading() {}
}

private final class RefreshFixtureManager: RemoteHostsManager {
    override func makeDownloader(for hosts: Hosts!, url: URL!) -> HostsDownloader! {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RefreshFixtureProtocol.self]
        return HostsDownloader(hosts: hosts, url: url, sessionConfiguration: config)
    }
}
