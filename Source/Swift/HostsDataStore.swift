import Foundation
import Combine

// MARK: - Notification Names
// These are defined as #define macros in Gas_Mask_Prefix.pch, which Swift cannot import.
// Mirror them here as NSNotification.Name constants.

extension NSNotification.Name {
    static let hostsFileCreated = NSNotification.Name("HostsFileCreatedNotification")
    static let hostsFileRemoved = NSNotification.Name("HostsFileRemovedNotification")
    static let hostsFileRenamed = NSNotification.Name("HostsFileRenamedNotification")
    static let hostsFileSaved = NSNotification.Name("HostsFileSavedNotification")
    static let hostsNodeNeedsUpdate = NSNotification.Name("HostsNodeNeedsUpdateNotification")
    static let hostsFileShouldBeRenamed = NSNotification.Name("HostsFileShouldBeRenamedNotification")
    static let hostsFileShouldBeSelected = NSNotification.Name("HostsFileShouldBeSelectedNotification")
    static let synchronizingStatusChanged = NSNotification.Name("SynchronizingStatusChangedNotification")
    static let allHostsFilesLoadedFromDisk = NSNotification.Name("AllHostsFilesLoadedFromDiskNotification")
    static let threadBusy = NSNotification.Name("ThreadBusyNotification")
    static let threadNotBusy = NSNotification.Name("ThreadNotBusyNotification")
}

// MARK: - HostsDataStore

final class HostsDataStore: ObservableObject {

    // MARK: Published Properties

    @Published var hostsGroups: [HostsGroup] = []
    @Published var selectedHosts: Hosts? {
        didSet {
            guard selectedHosts !== oldValue, !isSyncingSelection else { return }
            if let hosts = selectedHosts {
                HostsMainController.defaultInstance()?.select(hosts)
            }
        }
    }
    @Published var filesCount: Int = 0
    @Published var canRemoveFiles: Bool = false
    @Published var renamingHosts: Hosts?
    @Published var showingGlobalSearch = false
    @Published var showingHelp = false
    private(set) var editorSelection: NSRange?
    @Published private(set) var editorFocusRequest: UInt64 = 0
    @Published var isBusy: Bool = false
    @Published private(set) var rowRefreshToken: UInt64 = 0

    // MARK: Private

    private var notificationObservers: [NSObjectProtocol] = []
    private var isSyncingSelection = false
    private var busyCount = 0
    private var pendingRowRefresh = false

    // MARK: Init

    init() {
        observeNotifications()
        refreshGroups()
        refreshFilesCount()
        // Startup loads profiles before creating the editor, so the load
        // notification may already have fired. Read the current active object too.
        selectActiveHosts()
    }

    deinit {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: Refresh

    func refreshGroups() {
        guard let controller = HostsMainController.defaultInstance(),
              let content = controller.content as? [HostsGroup] else {
            hostsGroups = []
            return
        }
        hostsGroups = content
    }

    private func refreshFilesCount() {
        guard let controller = HostsMainController.defaultInstance() else { return }
        filesCount = Int(controller.filesCount())
        canRemoveFiles = controller.canRemoveFiles()
    }

    var canUpdateRemoteFiles: Bool {
        !isBusy && hostsGroups.contains { group in
            !group.synchronizing() && ((group.children as? [Hosts]) ?? []).contains { $0 is RemoteHosts }
        }
    }

    func canUpdate(_ remote: RemoteHosts) -> Bool {
        !isBusy && remote.url != nil && hostsGroups.contains { group in
            !group.synchronizing() && ((group.children as? [Hosts]) ?? []).contains { $0 === remote }
        }
    }

    func update(_ remote: RemoteHosts) {
        guard canUpdate(remote) else { return }
        _ = HostsMainController.defaultInstance()?.update(remote)
    }

    // MARK: Combined Composition

    var combinableHosts: [Hosts] {
        hostsGroups.flatMap { ($0.children as? [Hosts]) ?? [] }
            .filter { !($0 is CombinedHosts) }
    }

    func add(_ hosts: Hosts, to combined: CombinedHosts) {
        var files = (combined.hostsFiles() as? [Hosts]) ?? []
        guard combinableHosts.contains(where: { $0 === hosts }),
              !files.contains(where: { $0 === hosts }) else { return }
        files.append(hosts)
        update(combined, files: files)
    }

    func remove(_ hosts: Hosts, from combined: CombinedHosts) {
        var files = (combined.hostsFiles() as? [Hosts]) ?? []
        guard let index = files.firstIndex(where: { $0 === hosts }) else { return }
        files.remove(at: index)
        update(combined, files: files)
    }

    func move(_ hosts: Hosts, in combined: CombinedHosts, by offset: Int) {
        var files = (combined.hostsFiles() as? [Hosts]) ?? []
        guard let index = files.firstIndex(where: { $0 === hosts }),
              offset != 0, files.indices.contains(index + offset) else { return }
        files.remove(at: index)
        files.insert(hosts, at: index + offset)
        update(combined, files: files)
    }

    /// AppKit drop rows are insertion boundaries in the original array, including
    /// the boundary after the last row. No-op and cancelled drops leave it saved.
    @discardableResult
    func move(_ hosts: Hosts, in combined: CombinedHosts, toInsertionIndex insertion: Int) -> Bool {
        var files = (combined.hostsFiles() as? [Hosts]) ?? []
        guard let source = files.firstIndex(where: { $0 === hosts }),
              (0...files.count).contains(insertion) else { return false }
        let destination = insertion > source ? insertion - 1 : insertion
        guard destination != source else { return false }
        files.remove(at: source)
        files.insert(hosts, at: destination)
        update(combined, files: files)
        return true
    }

    private func update(_ combined: CombinedHosts, files: [Hosts]) {
        objectWillChange.send()
        // The model regenerates preview text, posts a row update and marks the
        // composition unsaved. Saving serializes this exact order.
        combined.setHostsFiles(files)
    }

    func focusEditor(range: NSRange? = nil) {
        editorSelection = range
        editorFocusRequest &+= 1
    }

    var activeHosts: Hosts? {
        hostsGroups.flatMap { ($0.children as? [Hosts]) ?? [] }.first { $0.active() }
    }

    // Both the selected Combined panel and the active-list footer analyze the
    // same value snapshots, never the owner's system hosts file.
    func conflictDocuments(for hosts: Hosts?) -> [ProfileSearchDocument] {
        guard let hosts else { return [] }
        let sources = (hosts as? CombinedHosts).map { ($0.hostsFiles() as? [Hosts]) ?? [] } ?? [hosts]
        return sources.compactMap { source in
            guard let path = source.path else { return nil }
            return ProfileSearchDocument(path: path, name: source.name() ?? "", remote: source is RemoteHosts,
                                         contents: source.contents() ?? "")
        }
    }

    var searchSources: [ProfileSearchSource] {
        combinableHosts.compactMap { hosts in
            guard let path = hosts.path else { return nil }
            return ProfileSearchSource(path: path, name: hosts.name() ?? "", remote: hosts is RemoteHosts,
                                       cachedContents: hosts.cachedContents())
        }
    }

    var searchDocuments: [ProfileSearchDocument] {
        combinableHosts.compactMap { hosts in
            guard let path = hosts.path else { return nil }
            return ProfileSearchDocument(path: path, name: hosts.name() ?? "", remote: hosts is RemoteHosts,
                                         contents: hosts.contents() ?? "")
        }
    }

    func openSearchResult(_ result: ProfileSearchMatch) {
        guard let hosts = combinableHosts.first(where: { $0.path == result.path }) else { return }
        let contents = (hosts.contents() ?? "") as NSString
        guard NSMaxRange(result.range) <= contents.length,
              contents.substring(with: result.range) == result.matchedText else { return }
        selectedHosts = hosts
        showingGlobalSearch = false
        focusEditor(range: result.range)
    }

    // MARK: Selection Sync

    private func selectActiveHosts() {
        guard let active = HostsMainController.defaultInstance()?.activeHostsFile() else { return }
        // Keep the native controller selection and SwiftUI editor in sync.
        // Selection does not activate the profile or write the system hosts file.
        selectedHosts = active
    }

    /// Called when the ObjC layer selects a hosts file (via notification).
    private func syncSelectionFromModel(_ hosts: Hosts?) {
        isSyncingSelection = true
        selectedHosts = hosts
        isSyncingSelection = false
    }

    // MARK: Row Refresh Coalescing

    /// Coalesces multiple rapid row-refresh notifications (e.g. from a download
    /// lifecycle that posts 9-12 notifications) into a single `objectWillChange`
    /// signal, so SwiftUI performs one re-render instead of many.
    /// Thread safety: Both the observer callbacks (queue: .main) and the
    /// DispatchQueue.main.async block execute on the main thread, so
    /// `pendingRowRefresh` access is serialized without explicit locking.
    private func scheduleRowRefresh() {
        guard !pendingRowRefresh else { return }
        pendingRowRefresh = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingRowRefresh = false
            self.rowRefreshToken &+= 1
        }
    }

    // MARK: Notification Observers

    private func observeNotifications() {
        let nc = NotificationCenter.default

        // Data change notifications — refresh groups and counts
        let refreshNames: [NSNotification.Name] = [
            .hostsFileCreated,
            .hostsFileRemoved,
            .hostsFileRenamed
        ]

        for name in refreshNames {
            let observer = nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refreshGroups()
                self?.refreshFilesCount()
            }
            notificationObservers.append(observer)
        }

        // All files loaded — refresh data then select the active file
        let loadedObserver = nc.addObserver(
            forName: .allHostsFilesLoadedFromDisk, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refreshGroups()
            self?.refreshFilesCount()
            self?.selectActiveHosts()
        }
        notificationObservers.append(loadedObserver)

        // Single-row refresh notifications — increment token to invalidate SwiftUI row views
        let rowRefreshNames: [NSNotification.Name] = [
            .hostsFileSaved,
            .hostsNodeNeedsUpdate,
            .synchronizingStatusChanged
        ]

        for name in rowRefreshNames {
            let observer = nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.scheduleRowRefresh()
            }
            notificationObservers.append(observer)
        }

        // UI action notifications
        let renameObserver = nc.addObserver(
            forName: .hostsFileShouldBeRenamed, object: nil, queue: .main
        ) { [weak self] notification in
            self?.renamingHosts = notification.object as? Hosts
        }
        notificationObservers.append(renameObserver)

        let selectObserver = nc.addObserver(
            forName: .hostsFileShouldBeSelected, object: nil, queue: .main
        ) { [weak self] notification in
            if let hosts = notification.object as? Hosts {
                self?.syncSelectionFromModel(hosts)
            }
        }
        notificationObservers.append(selectObserver)

        // Busy state notifications — posted from background threads, so use queue: .main
        let busyObserver = nc.addObserver(
            forName: .threadBusy, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.busyCount += 1
            self.isBusy = true
        }
        notificationObservers.append(busyObserver)

        let notBusyObserver = nc.addObserver(
            forName: .threadNotBusy, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if self.busyCount > 0 {
                self.busyCount -= 1
            }
            if self.busyCount == 0 {
                self.isBusy = false
            }
        }
        notificationObservers.append(notBusyObserver)
    }

}
