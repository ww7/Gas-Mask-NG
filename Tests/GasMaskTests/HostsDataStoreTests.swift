import XCTest
@testable import Gas_Mask

final class HostsDataStoreTests: XCTestCase {

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

}
