import SwiftUI

struct CombinedHostsPickerView: View {
    @ObservedObject var store: HostsDataStore

    var body: some View {
        if let combined = store.selectedHosts as? CombinedHosts {
            pickerContent(for: combined)
        }
    }

    private func pickerContent(for combined: CombinedHosts) -> some View {
        let included = (combined.hostsFiles() as? [Hosts]) ?? []
        let available = store.combinableHosts.filter { hosts in
            !included.contains { $0 === hosts }
        }

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Included Files")
                    .fontWeight(.semibold)
                Text("\(included.count) of \(store.combinableHosts.count)")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Menu {
                    ForEach(available, id: \.self) { hosts in
                        Button(hosts.name() ?? "") { store.add(hosts, to: combined) }
                    }
                } label: {
                    Label("Add File", systemImage: "plus")
                }
                .fixedSize()
                .disabled(available.isEmpty)
                .help("Add a hosts file to this Combined profile")
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Color(nsColor: .windowBackgroundColor))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if included.isEmpty {
                        Text("Use Add File to combine hosts files in the order you choose.")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(Array(included.enumerated()), id: \.offset) { index, hosts in
                            HStack(spacing: 8) {
                                Text("\(index + 1)")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18, alignment: .trailing)
                                Label(hosts.name() ?? "", systemImage: hosts is RemoteHosts ? "globe" : "doc")
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button {
                                    store.move(hosts, in: combined, by: -1)
                                } label: { Image(systemName: "chevron.up") }
                                .disabled(index == 0)
                                .accessibilityLabel("Move \(hosts.name() ?? "file") up")
                                .help("Move up")
                                Button {
                                    store.move(hosts, in: combined, by: 1)
                                } label: { Image(systemName: "chevron.down") }
                                .disabled(index == included.count - 1)
                                .accessibilityLabel("Move \(hosts.name() ?? "file") down")
                                .help("Move down")
                                Button {
                                    store.remove(hosts, from: combined)
                                } label: { Image(systemName: "minus.circle") }
                                .accessibilityLabel("Remove \(hosts.name() ?? "file") from Combined")
                                .help("Remove from this Combined profile")
                            }
                            .buttonStyle(.borderless)
                            .padding(.horizontal, 12)
                            .frame(height: 28)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            .frame(height: max(44, min(CGFloat(included.count) * 28 + 8, 152)))
        }
        .controlSize(.small)
        .font(.system(size: NSFont.smallSystemFontSize))
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
