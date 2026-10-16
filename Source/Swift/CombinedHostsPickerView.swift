import SwiftUI

struct CombinedHostsPickerView: View {
    @ObservedObject var store: HostsDataStore

    var body: some View {
        if let combined = store.selectedHosts as? CombinedHosts {
            let included = (combined.hostsFiles() as? [Hosts]) ?? []
            let available = store.combinableHosts.filter { hosts in
                !included.contains { $0 === hosts }
            }
            VStack(spacing: 0) {
                HStack {
                    Text("Included Files")
                        .fontWeight(.semibold)
                    Spacer(minLength: 4)
                    Menu {
                        ForEach(available, id: \.self) { hosts in
                            Button { store.add(hosts, to: combined) } label: {
                                Label(hosts.name() ?? "", systemImage: hosts is RemoteHosts ? "globe" : "doc")
                            }
                        }
                    } label: {
                        Label("Add File", systemImage: "plus")
                    }
                    .labelStyle(.iconOnly)
                    .fixedSize()
                    .disabled(available.isEmpty)
                    .help("Add File")
                    .accessibilityLabel("Add File")
                }
                .padding(.horizontal, 8)
                .frame(height: 30)
                Divider()
                if included.isEmpty {
                    Text("Use + to add a hosts file.")
                        .foregroundStyle(.secondary)
                        .padding(8)
                    Spacer(minLength: 0)
                } else {
                    CombinedFilesList(store: store, combined: combined)
                }
                CombinedConflictsView(store: store, combined: combined)
            }
            .controlSize(.small)
            .font(.system(size: NSFont.smallSystemFontSize))
            .background(Color(nsColor: .controlBackgroundColor))
            .accessibilityIdentifier("combined-sidebar")
        }
    }
}

// AppKit provides insertion markers, autoscroll and cancellation for local row
// drags. Only the leading grip can start a drag; the delete button stays clickable.
struct CombinedFilesList: NSViewRepresentable {
    @ObservedObject var store: HostsDataStore
    let combined: CombinedHosts

    func makeCoordinator() -> Coordinator { Coordinator(store: store, combined: combined) }

    func makeNSView(context: Context) -> NSScrollView {
        let table = CombinedFilesTableView()
        table.style = .plain
        table.headerView = nil
        table.rowHeight = 22
        table.intercellSpacing = .zero
        table.backgroundColor = .controlBackgroundColor
        table.selectionHighlightStyle = .none
        table.allowsEmptySelection = true
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.setAccessibilityIdentifier("combined-files")
        table.setAccessibilityLabel("Included Files")
        table.delegate = context.coordinator
        table.dataSource = context.coordinator
        table.registerForDraggedTypes([Coordinator.dragType])
        table.setDraggingSourceOperationMask(.move, forLocal: true)
        table.setDraggingSourceOperationMask([], forLocal: false)
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.documentView = table
        context.coordinator.refresh(table, store: store, combined: combined)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let table = scroll.documentView as? NSTableView else { return }
        context.coordinator.refresh(table, store: store, combined: combined)
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        static let dragType = NSPasteboard.PasteboardType("work.ww7.gasmask.combined-row")
        private var store: HostsDataStore
        private var combined: CombinedHosts
        private var files: [Hosts] = []
        private var names: [String] = []
        private var updatedDates: [Date?] = []
        private var draggedHosts: Hosts?
        private var draggedCombined: CombinedHosts?
        private var dragToken: String?

        init(store: HostsDataStore, combined: CombinedHosts) {
            self.store = store
            self.combined = combined
        }

        func refresh(_ table: NSTableView, store: HostsDataStore, combined: CombinedHosts) {
            let next = (combined.hostsFiles() as? [Hosts]) ?? []
            let nextNames = next.map { $0.name() ?? "" }
            let nextDates = next.map { ($0 as? RemoteHosts)?.updated }
            let changed = self.combined !== combined || files.count != next.count
                || !zip(files, next).allSatisfy { $0 === $1 } || names != nextNames || updatedDates != nextDates
            self.store = store
            self.combined = combined
            files = next
            names = nextNames
            updatedDates = nextDates
            if changed { table.reloadData() }
        }

        func numberOfRows(in tableView: NSTableView) -> Int { files.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let hosts = files[row]
            let cell = CombinedFileCell(name: names[row], isRemote: hosts is RemoteHosts, updated: updatedDates[row])
            cell.removeFile = { [weak self, weak hosts] in
                guard let self, let hosts else { return }
                self.store.remove(hosts, from: self.combined)
            }
            return cell
        }

        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            guard files.indices.contains(row) else { return nil }
            draggedHosts = files[row]
            draggedCombined = combined
            let token = UUID().uuidString
            dragToken = token
            let item = NSPasteboardItem()
            item.setString(token, forType: Self.dragType)
            return item
        }

        private func isLocalDrag(_ info: NSDraggingInfo, in table: NSTableView) -> Bool {
            (info.draggingSource as? NSTableView) === table
                && draggedCombined === combined && store.selectedHosts === combined
                && dragToken != nil && info.draggingPasteboard.string(forType: Self.dragType) == dragToken
        }

        func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo,
                       proposedRow row: Int, proposedDropOperation operation: NSTableView.DropOperation) -> NSDragOperation {
            guard isLocalDrag(info, in: tableView), (0...files.count).contains(row) else { return [] }
            var insertion = row
            if operation == .on, row < files.count {
                let point = tableView.convert(info.draggingLocation, from: nil)
                if point.y > tableView.rect(ofRow: row).midY { insertion += 1 }
            }
            tableView.setDropRow(insertion, dropOperation: .above)
            return .move
        }

        func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo,
                       row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
            guard isLocalDrag(info, in: tableView), let hosts = draggedHosts else { return false }
            return store.move(hosts, in: combined, toInsertionIndex: row)
        }

        func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession,
                       endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            draggedHosts = nil
            draggedCombined = nil
            dragToken = nil
        }
    }
}

final class CombinedFilesTableView: NSTableView {
    override func canDragRows(with rowIndexes: IndexSet, at mouseDownPoint: NSPoint) -> Bool {
        (4...24).contains(mouseDownPoint.x) && super.canDragRows(with: rowIndexes, at: mouseDownPoint)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(NSRect(x: 4, y: 0, width: 20, height: bounds.height), cursor: .openHand)
    }
}

private final class CombinedFileCell: NSTableCellView {
    var removeFile: (() -> Void)?

    init(name: String, isRemote: Bool, updated: Date?) {
        super.init(frame: .zero)
        let grip = NSImageView()
        grip.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "Drag \(name) to reorder")
        grip.contentTintColor = .secondaryLabelColor
        grip.toolTip = "Drag to reorder"
        let remove = NSButton(image: NSImage(systemSymbolName: "minus.circle", accessibilityDescription: "Remove \(name) from Combined")!, target: self, action: #selector(removeFromCombined))
        remove.isBordered = false
        remove.imageScaling = .scaleProportionallyDown
        remove.contentTintColor = .secondaryLabelColor
        remove.toolTip = "Remove from this Combined profile"
        remove.setAccessibilityLabel("Remove \(name) from Combined")
        let fileIcon = NSImageView()
        let typeDescription = isRemote ? "Remote file" : "Local file"
        fileIcon.image = NSImage(systemSymbolName: isRemote ? "globe" : "doc",
                                 accessibilityDescription: typeDescription)
        fileIcon.contentTintColor = .secondaryLabelColor
        fileIcon.toolTip = isRemote ? typeDescription + "\n" + RemoteUpdateStatus.summary(updated) : typeDescription
        let label = NSTextField(labelWithString: name)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let stack = NSStackView(views: [grip, remove, fileIcon, label])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            grip.widthAnchor.constraint(equalToConstant: 16),
            grip.heightAnchor.constraint(equalToConstant: 16),
            remove.widthAnchor.constraint(equalToConstant: 16),
            remove.heightAnchor.constraint(equalToConstant: 18),
            fileIcon.widthAnchor.constraint(equalToConstant: 16),
            fileIcon.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func removeFromCombined() { removeFile?() }
}

struct CombinedDomainConflict: Identifiable {
    let domain: String
    let sources: [CombinedConflictSource]
    var id: String { domain }
}

struct CombinedConflictSource: Identifiable {
    let path: String
    let name: String
    let remote: Bool
    let line: Int
    let address: String
    var id: String { "\(path):\(line):\(address)" }
}

enum CombinedConflictIndex {
    private struct Key: Hashable { let domain: String; let family: Int32 }

    static func conflicts(in documents: [ProfileSearchDocument]) -> [CombinedDomainConflict] {
        var records: [Key: [String: [CombinedConflictSource]]] = [:]
        var visited = Set<String>()
        for document in documents {
            guard visited.insert(document.path).inserted else { continue }
            var lineNumber = 0
            (document.contents as NSString).enumerateSubstrings(
                in: NSRange(location: 0, length: (document.contents as NSString).length),
                options: .byLines
            ) { line, _, _, stop in
                if Task<Never, Never>.isCancelled { stop.pointee = true; return }
                // enumerateSubstrings visits empty lines too with byLines.
                lineNumber += 1
                guard let line else { return }
                let uncommented = line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
                let fields = uncommented.split(whereSeparator: \.isWhitespace)
                guard fields.count > 1,
                      let address = HostsStatistics.canonicalAddress(String(fields[0])) else { return }
                let domains = Set(fields.dropFirst().map { HostsStatistics.normalizedHostname(String($0)) })
                for domain in domains where !domain.isEmpty {
                    let key = Key(domain: domain, family: address.family)
                    let source = CombinedConflictSource(path: document.path, name: document.name,
                        remote: document.remote, line: lineNumber, address: address.value)
                    records[key, default: [:]][document.path, default: []].append(source)
                }
            }
        }
        var conflicting: [String: [CombinedConflictSource]] = [:]
        for (key, sources) in records {
            if Task<Never, Never>.isCancelled { return [] }
            guard sources.count > 1 else { continue }
            let addressSets = Set(sources.values.map { Set($0.map(\.address)) })
            guard addressSets.count > 1 else { continue }
            conflicting[key.domain, default: []].append(contentsOf: sources.values.flatMap { $0 })
        }
        let order = Dictionary(documents.enumerated().map { ($1.path, $0) }, uniquingKeysWith: { first, _ in first })
        return conflicting.map { domain, sources in
            CombinedDomainConflict(domain: domain, sources: sources.sorted {
                let first = order[$0.path] ?? 0, second = order[$1.path] ?? 0
                if first != second { return first < second }
                if $0.line != $1.line { return $0.line < $1.line }
                return $0.address < $1.address
            })
        }.sorted { $0.domain.localizedStandardCompare($1.domain) == .orderedAscending }
    }
}

struct CombinedConflictsView: View {
    @ObservedObject var store: HostsDataStore
    let combined: CombinedHosts
    @State private var conflicts: [CombinedDomainConflict]?
    @State private var showingDetails = false

    private var documents: [ProfileSearchDocument] {
        ((combined.hostsFiles() as? [Hosts]) ?? []).compactMap { hosts in
            guard let path = hosts.path else { return nil }
            return ProfileSearchDocument(path: path, name: hosts.name() ?? "", remote: hosts is RemoteHosts,
                                         contents: hosts.contents() ?? "")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 5) {
                if let conflicts {
                    if conflicts.isEmpty {
                        Label("No cross-file conflicts", systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    } else {
                        Button { showingDetails = true } label: {
                            Label("\(conflicts.count) conflicting \(conflicts.count == 1 ? "domain" : "domains")",
                                  systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)
                        .help("Show addresses and source files for conflicting domains")
                        .accessibilityIdentifier("show-combined-conflicts")
                    }
                } else {
                    ProgressView().controlSize(.small)
                    Text("Checking domains…").foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .font(.caption)
            .padding(8)
        }
        .help("Compares address sets between included files, including unsaved edits. Repeats within one file and identical address sets are not flagged. IPv4 and IPv6 are checked separately.")
        .task(id: documents) {
            let snapshots = documents
            conflicts = nil
            let worker = Task.detached(priority: .utility) { CombinedConflictIndex.conflicts(in: snapshots) }
            let result = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
            guard !Task.isCancelled else { return }
            conflicts = result
        }
        .sheet(isPresented: $showingDetails) {
            CombinedConflictsDetailView(conflicts: conflicts ?? [])
        }
    }
}

struct CombinedConflictsDetailView: View {
    let conflicts: [CombinedDomainConflict]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Domain Conflicts").font(.headline)
            Text("Included files assign different address sets to the same domain. Repeats within a single file and identical sets across files are not conflicts here. IPv4 and IPv6 are checked separately.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            List(conflicts) { conflict in
                VStack(alignment: .leading, spacing: 6) {
                    Text(conflict.domain).fontWeight(.semibold).textSelection(.enabled)
                    ForEach(conflict.sources) { source in
                        HStack(alignment: .top, spacing: 12) {
                            Label("\(source.name) · line \(source.line)", systemImage: source.remote ? "globe" : "doc")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(source.address).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        }
                        .help(source.path)
                    }
                }.padding(.vertical, 5)
            }
            Text("Edit the source profiles to resolve conflicts. No addresses are changed automatically.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack { Spacer(); Button("Close") { dismiss() }.keyboardShortcut(.cancelAction) }
        }
        .padding(20).frame(width: 600, height: 420)
    }
}
