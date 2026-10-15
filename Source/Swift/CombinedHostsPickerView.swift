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
            let changed = self.combined !== combined || files.count != next.count
                || !zip(files, next).allSatisfy { $0 === $1 } || names != nextNames
            self.store = store
            self.combined = combined
            files = next
            names = nextNames
            if changed { table.reloadData() }
        }

        func numberOfRows(in tableView: NSTableView) -> Int { files.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let hosts = files[row]
            let cell = CombinedFileCell(name: names[row], isRemote: hosts is RemoteHosts)
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

    init(name: String, isRemote: Bool) {
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
        fileIcon.toolTip = typeDescription
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
