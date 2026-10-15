import SwiftUI

struct CombinedHostsPickerView: View {
    @ObservedObject var store: HostsDataStore

    var body: some View {
        if let combined = store.selectedHosts as? CombinedHosts {
            pickerContent(for: combined)
        }
    }

    // MARK: - Picker Content

    @ViewBuilder
    private func pickerContent(for combined: CombinedHosts) -> some View {
        let allFiles = allNonCombinedHosts()
        let includedFiles = (combined.hostsFiles() as? [Hosts]) ?? []

        VStack(spacing: 0) {
            HStack {
                Text("Included Files")
                    .font(.system(size: NSFont.smallSystemFontSize, weight: .semibold))
                Spacer()
                Text("\(includedFiles.count) of \(allFiles.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Color(nsColor: .windowBackgroundColor))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if allFiles.isEmpty {
                        Text("No hosts files available to combine.")
                            .foregroundStyle(.secondary)
                            .font(.system(size: NSFont.smallSystemFontSize))
                            .padding(.horizontal, 12)
                    } else {
                        ForEach(allFiles, id: \.self) { hosts in
                            Toggle(isOn: toggleBinding(for: hosts, in: combined)) {
                                Label(hosts.name() ?? "", systemImage: hosts is RemoteHosts ? "globe" : "doc")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .toggleStyle(.checkbox)
                            .controlSize(.small)
                            .font(.system(size: NSFont.smallSystemFontSize))
                            .padding(.horizontal, 12)
                            .frame(height: 24)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            .frame(height: max(32, min(CGFloat(allFiles.count) * 24 + 8, 152)))
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Toggle Binding

    private func toggleBinding(for hosts: Hosts, in combined: CombinedHosts) -> Binding<Bool> {
        Binding(
            get: {
                let current = (combined.hostsFiles() as? [Hosts]) ?? []
                return current.contains { $0 === hosts }
            },
            set: { isOn in
                var files = (combined.hostsFiles() as? [Hosts]) ?? []
                if isOn {
                    if !files.contains(where: { $0 === hosts }) {
                        files.append(hosts)
                    }
                } else {
                    files.removeAll { $0 === hosts }
                }
                combined.setHostsFiles(files)
                store.hostsGroups = store.hostsGroups
            }
        )
    }

    // MARK: - Helpers

    private func allNonCombinedHosts() -> [Hosts] {
        var result: [Hosts] = []
        for group in store.hostsGroups {
            let children = (group.children as? [Hosts]) ?? []
            for hosts in children where !(hosts is CombinedHosts) {
                result.append(hosts)
            }
        }
        return result
    }
}
