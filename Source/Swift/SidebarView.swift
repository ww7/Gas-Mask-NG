import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @ObservedObject var store: HostsDataStore

    @State private var editingName: String = ""
    @State private var isEditing = false
    @FocusState private var renameFieldFocused: Bool
    @State private var renameError: String?
    @State private var hostsToRemove: Hosts?

    var body: some View {
        List(selection: $store.selectedHosts) {
            ForEach(sidebarGroups, id: \.self) { group in
                let children = ((group.children as? [Hosts]) ?? []).sorted {
                    ($0.name() ?? "").localizedStandardCompare($1.name() ?? "") == .orderedAscending
                }
                Section(header: HostsRowView(hosts: group, isGroup: true, refreshToken: store.rowRefreshToken)) {
                    ForEach(children, id: \.self) { hosts in
                        rowContent(for: hosts)
                            .foregroundColor(Color(nsColor: .labelColor))
                            .frame(maxWidth: .infinity, minHeight: 20, maxHeight: 20)
                            .padding(.horizontal, 4)
                            .background {
                                if store.selectedHosts === hosts {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color(nsColor: .unemphasizedSelectedContentBackgroundColor))
                                }
                            }
                            .tag(hosts)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                    }
                }
                .listSectionSeparator(.hidden)
                .onDrop(of: [.fileURL, .url], delegate: SidebarDropDelegate(group: group))
            }
        }
        .background(SidebarListAppearance())
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.defaultMinListRowHeight, 20)
        .controlSize(.small)
        .onChange(of: store.renamingHosts) { newValue in
            if let hosts = newValue {
                beginRename(hosts)
            }
        }
        .onChange(of: store.selectedHosts) { newValue in
            if isEditing, let hosts = store.renamingHosts, newValue !== hosts {
                commitRename(hosts)
            }
        }
        .alert("Rename Error", isPresented: Binding(
            get: { renameError != nil },
            set: { if !$0 { renameError = nil } }
        )) {
            Button("OK") { renameError = nil }
        } message: {
            Text(renameError ?? "")
        }
        .alert("Remove Hosts File", isPresented: Binding(
            get: { hostsToRemove != nil },
            set: { if !$0 { hostsToRemove = nil } }
        )) {
            Button("Cancel", role: .cancel) { hostsToRemove = nil }
            Button("Remove", role: .destructive) {
                if let hosts = hostsToRemove {
                    HostsMainController.defaultInstance()?.removeHostsFile(hosts, moveToTrash: true)
                }
                hostsToRemove = nil
            }
        } message: {
            Text("Are you sure you want to remove \"\(hostsToRemove?.name() ?? "")\"? The file will be moved to Trash.")
        }
    }

    // Presentation order only: retain the model's next/previous activation order.
    private var sidebarGroups: [HostsGroup] {
        let combined = store.hostsGroups.filter { $0.name() == "COMBINED" }
        return combined + store.hostsGroups.filter { $0.name() != "COMBINED" }
    }

    // MARK: - Row Content

    @ViewBuilder
    private func rowContent(for hosts: Hosts) -> some View {
        if isEditing, store.renamingHosts === hosts {
            HostsFileRow(hosts: hosts, refreshToken: store.rowRefreshToken, isEditing: true) {
                renameField(for: hosts)
            }
        } else {
            HostsRowView(hosts: hosts, isGroup: false, refreshToken: store.rowRefreshToken)
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture(count: 2).onEnded {
                    requestRename(hosts)
                })
                .contextMenu { contextMenuItems(for: hosts) }
        }
    }

    // MARK: - Inline Rename

    private func renameField(for hosts: Hosts) -> some View {
        TextField("Name", text: $editingName)
        .textFieldStyle(.plain)
        .focused($renameFieldFocused)
        .task {
            // The field must be inserted before requesting keyboard focus.
            await Task.yield()
            if isEditing, store.renamingHosts === hosts {
                renameFieldFocused = true
            }
        }
        .onChange(of: renameFieldFocused) { focused in
            if !focused { commitRename(hosts) }
        }
        .onSubmit {
            commitRename(hosts, focusEditor: true)
        }
        .onExitCommand {
            cancelRename()
        }
    }

    private func requestRename(_ hosts: Hosts) {
        store.selectedHosts = hosts
        store.renamingHosts = hosts
    }

    private func beginRename(_ hosts: Hosts) {
        store.selectedHosts = hosts
        editingName = hosts.name() ?? ""
        isEditing = true
    }

    private func commitRename(_ hosts: Hosts, focusEditor: Bool = false) {
        // Submit and focus loss can arrive in the same turn. Finish the session
        // first so the model is renamed once and the inline field always closes.
        guard isEditing, store.renamingHosts === hosts else { return }
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        cancelRename()
        guard !trimmed.isEmpty, trimmed != hosts.name() else {
            if focusEditor { store.focusEditor() }
            return
        }

        if trimmed.contains("/") {
            renameError = "File name cannot contain forward slash."
            return
        }

        guard let controller = HostsMainController.defaultInstance() else { return }
        let renamed = controller.rename(hosts, to: trimmed)
        if renamed {
            NotificationCenter.default.post(name: .hostsFileRenamed, object: hosts)
            if focusEditor { store.focusEditor() }
        } else {
            renameError = "A file with that name already exists."
        }
    }

    private func cancelRename() {
        renameFieldFocused = false
        isEditing = false
        store.renamingHosts = nil
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for hosts: Hosts) -> some View {
        if !hosts.saved() {
            Button("Save") {
                HostsMainController.defaultInstance()?.save(hosts)
            }
        }

        if !hosts.active() || hosts.systemApplyPending {
            Button("Activate") {
                HostsMainController.defaultInstance()?.activateHostsFile(hosts)
            }
            .disabled(!hosts.exists)
        }

        Button("Show In Finder") {
            if let path = hosts.path {
                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
            }
        }
        .disabled(!hosts.exists)

        if let remote = hosts as? RemoteHosts {
            Divider()
            Button {
                store.update(remote)
            } label: {
                Label("Update Remote File", systemImage: "icloud.and.arrow.down")
            }
            .disabled(!store.canUpdate(remote))
        } else if hosts is CombinedHosts {
            Divider()
            Button {
                ApplicationController.defaultInstance()?.updateAndSynchronize(nil)
            } label: {
                Label("Update Remote Files", systemImage: "icloud.and.arrow.down")
            }
            .disabled(!store.canUpdateRemoteFiles)
        }

        if let remote = hosts as? RemoteHosts {
            Button("Open in Browser") {
                if let url = remote.url {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Move to Local") {
                HostsMainController.defaultInstance()?.move(hosts, toControllerClass: LocalHostsController.self)
            }
            .disabled(!hosts.exists)
        }

        Divider()

        Button("Rename") {
            requestRename(hosts)
        }

        Divider()

        if store.canRemoveFiles {
            Button("Remove") {
                hostsToRemove = hosts
            }
        }
    }
}

// MARK: - Drop Support

extension SidebarView {

    struct SidebarDropDelegate: DropDelegate {
        let group: HostsGroup

        func validateDrop(info: DropInfo) -> Bool {
            info.hasItemsConforming(to: [.fileURL, .url])
        }

        func performDrop(info: DropInfo) -> Bool {
            guard let controller = HostsMainController.defaultInstance() else { return false }

            let providers = info.itemProviders(for: [.fileURL, .url])
            var handled = false
            for provider in providers {
                if provider.canLoadObject(ofClass: URL.self) {
                    handled = true
                    _ = provider.loadObject(ofClass: URL.self) { url, error in
                        if let error {
                            NSLog("Drop URL load failed: %@", error.localizedDescription)
                            return
                        }
                        guard let url else { return }
                        DispatchQueue.main.async {
                            if url.isFileURL {
                                _ = controller.createHosts(fromLocalURL: url, to: group)
                            } else {
                                _ = controller.createHosts(from: url, to: group)
                            }
                        }
                    }
                }
            }
            return handled
        }
    }
}

// Appearance only. Keyboard and text editing use normal SwiftUI/AppKit handling.
private struct SidebarListAppearance: NSViewRepresentable {
    func makeNSView(context: Context) -> AppearanceView {
        AppearanceView()
    }

    func updateNSView(_ view: AppearanceView, context: Context) {
        view.needsLayout = true
    }

    final class AppearanceView: NSView {

        // The List owns its table/delegate. Change only presentation, retaining
        // native selection, keyboard navigation and accessibility behavior.
        override func layout() {
            super.layout()
            guard let content = window?.contentView else { return }
            styleSidebarTables(in: content)
        }

        private func contains(_ table: NSTableView) -> Bool {
            guard let scroll = table.enclosingScrollView else { return false }
            let sidebarFrame = convert(bounds, to: nil)
            let scrollFrame = scroll.convert(scroll.bounds, to: nil)
            return sidebarFrame.contains(NSPoint(x: scrollFrame.midX, y: scrollFrame.midY))
        }

        private func styleSidebarTables(in view: NSView) {
            if let table = view as? NSTableView, contains(table) {
                table.selectionHighlightStyle = .none
                // A navigation sidebar has ordinary section labels, not floating
                // table headers with a separator/shadow under the first group.
                if table.floatsGroupRows { table.floatsGroupRows = false }
                if table.intercellSpacing.height != 0 {
                    table.intercellSpacing = NSSize(width: table.intercellSpacing.width, height: 0)
                }
                return
            }
            for child in view.subviews { styleSidebarTables(in: child) }
        }

    }
}
