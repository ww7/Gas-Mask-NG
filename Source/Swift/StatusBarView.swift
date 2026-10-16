import SwiftUI
import Darwin

enum HostsStatistics {
    // Count unique, enabled hostnames, including aliases, after a valid address.
    // Full-line and inline comments never contribute to the active count.
    static func uniqueHostCount(_ contents: String) -> Int {
        var names = Set<String>()
        for line in contents.split(whereSeparator: \.isNewline) {
            if Task<Never, Never>.isCancelled { return 0 }
            let uncommented = line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
            let fields = uncommented.split(whereSeparator: \.isWhitespace)
            guard fields.count > 1 else { continue }
            guard canonicalAddress(String(fields[0])) != nil else { continue }
            for field in fields.dropFirst() {
                let name = normalizedHostname(String(field))
                if !name.isEmpty { names.insert(name) }
            }
        }
        return names.count
    }

    static func normalizedHostname(_ name: String) -> String {
        let lower = name.lowercased()
        return lower.hasSuffix(".") ? String(lower.dropLast()) : lower
    }

    static func canonicalAddress(_ value: String) -> (family: Int32, value: String)? {
        var address = in6_addr()
        let family: Int32 = value.withCString { pointer in
            if inet_pton(AF_INET, pointer, &address) == 1 { return AF_INET }
            if inet_pton(AF_INET6, pointer, &address) == 1 { return AF_INET6 }
            return 0
        }
        guard family != 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        guard inet_ntop(family, &address, &buffer, socklen_t(buffer.count)) != nil else { return nil }
        return (family, String(cString: buffer))
    }

}

struct StatusBarView: View {
    @ObservedObject var store: HostsDataStore
    @State private var count: Int?
    @State private var conflicts: [CombinedDomainConflict]?
    @State private var showingConflicts = false

    private var documents: [ProfileSearchDocument] { store.conflictDocuments(for: store.activeHosts) }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                if let active = store.activeHosts {
                    Text("Active: \(active.name() ?? "")")
                        .lineLimit(1).truncationMode(.middle)
                    if active.systemApplyPending {
                        Text("Pending · Activate to apply").foregroundStyle(.orange)
                            .help("The cached list has changed. Activate it to authorize system changes for this app session.")
                    }
                    if let count {
                        Text("· \(count) \(count == 1 ? "host" : "hosts")")
                            .fixedSize()
                            .help("Unique hostnames in the active profile, including aliases; comments are excluded")
                    }
                    if let conflicts {
                        Button { showingConflicts = true } label: {
                            Label("\(conflicts.count) \(conflicts.count == 1 ? "conflict" : "conflicts")",
                                  systemImage: conflicts.isEmpty ? "checkmark.circle" : "exclamationmark.triangle")
                                .foregroundStyle(conflicts.isEmpty ? Color.secondary : Color.orange)
                        }
                        .buttonStyle(.plain)
                        .help("Show conflicts in the active list, including unsaved or pending changes")
                        .accessibilityIdentifier("show-active-conflicts")
                    }
                } else {
                    Text("No active profile")
                }
                Spacer(minLength: 0)
                if store.isBusy {
                    ProgressView().controlSize(.small).help("Updating hosts files")
                }
                Button { store.showingHelp = true } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.plain)
                .help("Keyboard shortcuts and help")
                .accessibilityLabel("Keyboard shortcuts and help")
            }
            .font(.system(size: NSFont.smallSystemFontSize))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .frame(height: 24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task(id: documents) {
            let snapshots = documents
            count = nil
            conflicts = nil
            let worker = Task.detached(priority: .utility) {
                (HostsStatistics.uniqueHostCount(snapshots.map(\.contents).joined(separator: "\n")),
                 CombinedConflictIndex.conflicts(in: snapshots))
            }
            let result = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
            guard !Task.isCancelled else { return }
            count = result.0
            conflicts = result.1
        }
        .sheet(isPresented: $showingConflicts) {
            CombinedConflictsDetailView(conflicts: conflicts ?? [], listName: store.activeHosts?.name())
        }
    }
}

struct EditorHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gas Mask Help").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 7) {
                shortcut("Find in the displayed profile", "⌘F")
                shortcut("Find next / previous", "⌘G / ⇧⌘G")
                shortcut("Find in all local and remote lists", "⇧⌘F")
                shortcut("Comment / uncomment line or selection", "⌘/")
                shortcut("Save the selected profile", "⌘S")
                shortcut("Undo / redo", "⌘Z / ⇧⌘Z")
                shortcut("Larger / smaller / actual text size", "⌘+ / ⌘− / ⌘0")
            }
            Text("Configure global window-toggle, profile-switching and update shortcuts in Settings.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("The checkmark marks the active profile. Selecting another profile only opens it for viewing; Activate applies it to the system hosts file.")
                    Text("Remote files and Combined previews are read-only. Move a Remote file to Local to edit it; it will stop updating from its URL. Edit the source files or drag the Included Files rows to change a Combined profile.")
                    Text("System changes require administrator approval once per app session. Background updates never prompt; Pending means the cached list needs Activate before it affects the system. No permanent system-file write permission is granted.")
                    Text("Update in the toolbar refreshes all Remote files. Update Remote File in a profile’s context menu refreshes only that file.")
                    Text("The footer shows unique hostnames and conflicting domains in the active list. Click the conflict count for addresses, source lists and line numbers. Comments and identical repeats are ignored, and IPv4/IPv6 are separate. Counts include unsaved or Pending contents; save or Activate to apply them.")
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 190)
            HStack { Spacer(); Button("Close") { dismiss() }.keyboardShortcut(.cancelAction) }
        }
        .font(.system(size: NSFont.smallSystemFontSize))
        .padding(24).frame(width: 540)
    }

    private func shortcut(_ title: String, _ keys: String) -> some View {
        GridRow { Text(title); Text(keys).foregroundStyle(.secondary) }
    }
}
