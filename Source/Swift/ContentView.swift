import SwiftUI

struct ContentView: View {
    @ObservedObject var store: HostsDataStore

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                if let remote = store.selectedHosts as? RemoteHosts {
                    RemoteUpdateView(remote: remote, refreshToken: store.rowRefreshToken)
                    Divider()
                }
                HostsTextViewRepresentable(
                    selectedHosts: store.selectedHosts,
                    contentToken: store.rowRefreshToken,
                    focusRequest: store.editorFocusRequest,
                    onTextChange: { [weak store] newText in
                        store?.selectedHosts?.setContents(newText)
                    },
                    selectionRange: store.editorSelection
                )
                .clipped()
                .frame(minWidth: 80, maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 80, maxWidth: .infinity, maxHeight: .infinity)
            if store.selectedHosts is CombinedHosts {
                CombinedHostsPickerView(store: store)
                    .frame(minWidth: 160, idealWidth: 200, maxWidth: 240, maxHeight: .infinity)
            }
        }
    }
}

// Value snapshots let global search run off the main thread without passing the
// mutable ObjC profile model to a worker. Combined previews are excluded by store.
struct ProfileSearchDocument: Hashable {
    let path: String
    let name: String
    let remote: Bool
    let contents: String
}

struct ProfileSearchMatch: Identifiable {
    let path: String
    let name: String
    let remote: Bool
    let line: Int
    let text: String
    let range: NSRange
    let matchedText: String
    var id: String { "\(path):\(range.location)" }
}

struct ProfileSearchRequest: Hashable {
    let query: String
    let documents: [ProfileSearchDocument]
}

enum ProfileSearchIndex {
    static let resultLimit = 300

    static func matches(_ query: String, documents: [ProfileSearchDocument]) -> [ProfileSearchMatch] {
        guard !query.isEmpty else { return [] }
        var matches: [ProfileSearchMatch] = []
        for document in documents {
            let content = document.contents as NSString
            var offset = 0
            var line = 1
            while offset < content.length {
                if Task<Never, Never>.isCancelled { return [] }
                let lineRange = content.lineRange(for: NSRange(location: offset, length: 0))
                let text = content.substring(with: lineRange).trimmingCharacters(in: .newlines)
                let range = (text as NSString).range(of: query, options: [.caseInsensitive, .diacriticInsensitive])
                if range.location != NSNotFound {
                    matches.append(ProfileSearchMatch(path: document.path, name: document.name,
                        remote: document.remote, line: line, text: text,
                        range: NSRange(location: offset + range.location, length: range.length),
                        matchedText: (text as NSString).substring(with: range)))
                    if matches.count == resultLimit { return matches }
                }
                offset = NSMaxRange(lineRange)
                line += 1
            }
        }
        return matches
    }
}

struct ProfileSearchView: View {
    @ObservedObject var store: HostsDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [ProfileSearchMatch] = []
    @State private var searching = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Find in All Profiles").font(.headline)
            TextField("Search local and downloaded remote files", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .accessibilityLabel("Search all profiles")
                .onSubmit { if let result = results.first { store.openSearchResult(result) } }
            List(results) { result in
                Button {
                    store.openSearchResult(result)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("\(result.name) · \(result.line)", systemImage: result.remote ? "globe" : "doc")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(result.text).font(.system(.body, design: .monospaced))
                            .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open \(result.name) at line \(result.line)")
            }
            .overlay {
                if !searching && results.isEmpty {
                    Text(query.isEmpty ? "Combined previews are excluded to avoid duplicate results." : "No matches")
                        .foregroundStyle(.secondary).padding()
                }
            }
            HStack {
                if searching { ProgressView().controlSize(.small) }
                Text(results.count == ProfileSearchIndex.resultLimit
                    ? "First 300 matching lines — refine your search"
                    : "\(results.count) matching lines")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 620, height: 420)
        .onAppear { searchFocused = true }
        .task(id: ProfileSearchRequest(query: query, documents: store.searchDocuments)) {
            let documents = store.searchDocuments
            let term = query
            searching = true
            results = []
            let worker = Task.detached(priority: .userInitiated) {
                ProfileSearchIndex.matches(term, documents: documents)
            }
            let matches = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
            guard !Task.isCancelled else { return }
            results = matches
            searching = false
        }
    }
}


enum RemoteUpdateStatus {
    static func summary(_ date: Date?) -> String {
        guard let date else { return "No successful update recorded" }
        return "Last successful update: " + date.formatted(date: .abbreviated, time: .shortened)
    }
}

struct RemoteUpdateView: View {
    let remote: RemoteHosts
    let refreshToken: UInt64

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
            Text(RemoteUpdateStatus.summary(remote.updated))
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
            if remote.error() != nil {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .help("The last attempt failed; the previous successful update time is retained")
            }
        }
        .font(.system(size: NSFont.smallSystemFontSize))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8).frame(height: 26)
        .background(Color(nsColor: .windowBackgroundColor))
        .help(remote.updated.map { "Last successful download or check with no changes: " + $0.formatted(date: .complete, time: .complete) }
            ?? "This file has no successful update time recorded yet")
        .accessibilityIdentifier("remote-update-status")
    }
}
