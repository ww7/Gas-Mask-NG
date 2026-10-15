import SwiftUI

struct HostsRowView: View {
    let hosts: Hosts
    let isGroup: Bool
    // Unused in body; exists to invalidate SwiftUI's byte-comparison cache when Hosts properties change.
    let refreshToken: UInt64

    @State private var showingOfflinePopover = false

    var body: some View {
        if isGroup {
            groupRow
        } else {
            HostsFileRow(hosts: hosts, refreshToken: refreshToken) {
                Text(hosts.name() ?? "")
                    .lineLimit(1)
                    .opacity(hosts.enabled() ? 1.0 : 0.5)
            }
        }
    }

    // MARK: - Group Row

    private var groupRow: some View {
        HStack(spacing: 4) {
            Text(hosts.name() ?? "")
                .font(.system(size: NSFont.smallSystemFontSize, weight: .semibold))
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
            Spacer()
            groupBadges
        }
    }

    @ViewBuilder
    private var groupBadges: some View {
        if let group = hosts as? HostsGroup {
            if !group.online() {
                Button {
                    showingOfflinePopover = true
                } label: {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Offline")
                .accessibilityLabel("Show offline details")
                .popover(isPresented: $showingOfflinePopover) {
                    ErrorPopoverView(
                        title: "No Internet Connection",
                        description: "Can't update hosts files because you are not connected to the Internet."
                    )
                }
            }
            if group.synchronizing() {
                ProgressView()
                    .controlSize(.small)
                    .help("Synchronizing")
            }
        }
        if let error = hosts.error() {
            HostsErrorBadge(error: error)
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        Self.accessibilityDescription(for: hosts)
    }

    static func accessibilityDescription(for hosts: Hosts) -> String {
        var parts: [String] = []
        parts.append(hosts.name() ?? "")
        if hosts.active() { parts.append("active") }
        if !hosts.saved() { parts.append("unsaved") }
        if hosts.error() != nil { parts.append("has error") }
        if !hosts.enabled() { parts.append("disabled") }
        return parts.joined(separator: ", ")
    }
}

// A shared row keeps the icon, name column and status indicators in the same
// positions while the name switches between a label and an inline TextField.
struct HostsFileRow<Name: View>: View {
    let hosts: Hosts
    let refreshToken: UInt64
    let isEditing: Bool
    private let name: Name

    init(hosts: Hosts, refreshToken: UInt64, isEditing: Bool = false, @ViewBuilder name: () -> Name) {
        self.hosts = hosts
        self.refreshToken = refreshToken
        self.isEditing = isEditing
        self.name = name()
    }

    var body: some View {
        HStack(spacing: 4) {
            fileIcon.frame(width: 16, height: 16)
            name
                .font(.system(size: NSFont.smallSystemFontSize))
                .frame(maxWidth: .infinity, alignment: .leading)
            if hosts.active() {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                    .accessibilityLabel("Active")
            }
            if let error = hosts.error() {
                HostsErrorBadge(error: error)
            }
            if !hosts.saved() {
                Circle()
                    .fill(.blue)
                    .frame(width: 6, height: 6)
                    .accessibilityLabel("Unsaved")
            }
        }
        .accessibilityElement(children: isEditing ? .contain : .combine)
        .accessibilityLabel(HostsRowView.accessibilityDescription(for: hosts))
    }

    @ViewBuilder
    private var fileIcon: some View {
        if hosts is CombinedHosts {
            Image(systemName: "doc.on.doc").foregroundStyle(.secondary)
        } else if hosts is RemoteHosts {
            Image(systemName: "globe")
                .foregroundStyle(hosts.enabled() ? .secondary : .tertiary)
        } else {
            Image(systemName: "doc").foregroundStyle(.secondary)
        }
    }
}

private struct HostsErrorBadge: View {
    let error: Error
    @State private var showingErrorPopover = false

    var body: some View {
        Button {
            showingErrorPopover = true
        } label: {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.yellow)
        }
        .buttonStyle(.plain)
        .help(error.description ?? "Error")
        .accessibilityLabel("Show error details")
        .popover(isPresented: $showingErrorPopover) {
            ErrorPopoverView(title: errorTitle, description: error.description, url: error.url)
        }
    }

    private var errorTitle: String {
        switch error.type {
        case UInt(NetworkOffline): return "No Internet Connection"
        case UInt(ServerNotFound): return "Server Not Found"
        case UInt(FileNotFound): return "Hosts File Not Found"
        case UInt(FailedToDownload): return "Failed to Download"
        case UInt(BadContentType): return "Bad Content"
        case UInt(InvalidMobileMeAccount): return "Invalid Account"
        default: return "Error"
        }
    }
}
