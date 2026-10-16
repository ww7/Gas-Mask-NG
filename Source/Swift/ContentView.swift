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

struct ProfileSearchSource {
    let path: String
    let name: String
    let remote: Bool
    let cachedContents: String?
}

struct PreparedSearchDocument {
    let document: ProfileSearchDocument
    let text: NSString
    let lines: [NSRange]

    init(_ document: ProfileSearchDocument) {
        self.document = document
        text = document.contents as NSString
        var ranges: [NSRange] = []
        var offset = 0
        while offset < text.length {
            if Task<Never, Never>.isCancelled { break }
            var end = 0
            var contentsEnd = 0
            text.getLineStart(nil, end: &end, contentsEnd: &contentsEnd,
                              for: NSRange(location: offset, length: 0))
            ranges.append(NSRange(location: offset, length: contentsEnd - offset))
            offset = end
        }
        lines = ranges
    }
}

struct ProfileSearchRequest: Hashable {
    let query: String
    let regex: Bool
    let revision: UInt64
}

enum ProfileSearchIndex {
    static let resultLimit = 300

    static func prepare(_ sources: [ProfileSearchSource]) -> [PreparedSearchDocument] {
        sources.compactMap { source in
            guard !Task<Never, Never>.isCancelled else { return nil }
            // Cached in-memory edits take priority; untouched files are read only
            // once per snapshot, on the worker, never from the SwiftUI body.
            guard let contents = source.cachedContents ?? (try? String(contentsOfFile: source.path, encoding: .utf8)) else { return nil }
            return PreparedSearchDocument(ProfileSearchDocument(path: source.path, name: source.name,
                remote: source.remote, contents: contents))
        }
    }

    static func matches(_ query: String, documents: [ProfileSearchDocument]) -> [ProfileSearchMatch] {
        matches(query, prepared: documents.map(PreparedSearchDocument.init))
    }

    static func matches(_ query: String, prepared: [PreparedSearchDocument], regex: NSRegularExpression? = nil) -> [ProfileSearchMatch] {
        guard !query.isEmpty else { return [] }
        var matches: [ProfileSearchMatch] = []
        for item in prepared {
            let document = item.document
            for (index, lineRange) in item.lines.enumerated() {
                if Task<Never, Never>.isCancelled { return [] }
                let range: NSRange
                if let regex {
                    var found = NSRange(location: NSNotFound, length: 0)
                    // Progress callbacks allow cancellation even inside expensive
                    // expressions; stop after the first match in each line.
                    regex.enumerateMatches(in: document.contents, options: [.reportProgress], range: lineRange) { result, _, stop in
                        if Task<Never, Never>.isCancelled { stop.pointee = true }
                        if let result { found = result.range; stop.pointee = true }
                    }
                    range = found
                } else {
                    range = item.text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], range: lineRange)
                }
                if range.location != NSNotFound {
                    matches.append(ProfileSearchMatch(path: document.path, name: document.name,
                        remote: document.remote, line: index + 1, text: item.text.substring(with: lineRange),
                        range: range, matchedText: item.text.substring(with: range)))
                    if matches.count == resultLimit { return matches }
                }
            }
        }
        return matches
    }
}

struct ProfileSearchView: View {
    @ObservedObject var store: HostsDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var useRegex = false
    @State private var results: [ProfileSearchMatch] = []
    @State private var documents: [PreparedSearchDocument] = []
    @State private var revision: UInt64 = 0
    @State private var preparing = true
    @State private var searching = false
    @State private var patternError: String?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Find in All Lists").font(.headline)
            HStack {
                TextField("Search local and downloaded remote lists", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
                    .accessibilityLabel("Search all lists")
                    .onSubmit { if !searching && !preparing, let result = results.first { store.openSearchResult(result) } }
                Toggle(".*", isOn: $useRegex)
                    .toggleStyle(.button).font(.system(.body, design: .monospaced))
                    .help("Use a regular expression (case-insensitive, one result per matching line)")
                    .accessibilityLabel("Regular expression")
            }
            if let patternError { Text(patternError).font(.caption).foregroundStyle(.red).lineLimit(2) }
            List(results) { result in
                Button { store.openSearchResult(result) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: result.remote ? "globe" : "doc").frame(width: 14)
                        Text(result.name).frame(width: 100, alignment: .leading).truncationMode(.middle)
                        Text("\(result.line)").monospacedDigit().foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                        Text(result.text).font(.system(size: NSFont.smallSystemFontSize, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.system(size: NSFont.smallSystemFontSize))
                    .lineLimit(1).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                .help("\(result.name), line \(result.line): \(result.text)")
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 22)
            .overlay {
                if !searching && !preparing && results.isEmpty && patternError == nil {
                    Text(query.isEmpty ? "Combined previews are excluded to avoid duplicate results." : "No matches")
                        .foregroundStyle(.secondary).padding()
                }
            }
            HStack {
                if searching || preparing { ProgressView().controlSize(.small) }
                Text(results.count == ProfileSearchIndex.resultLimit
                    ? "First 300 matching lines — refine your search"
                    : "\(results.count) matching lines")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 720, height: 440)
        .onAppear { searchFocused = true }
        .task(id: store.rowRefreshToken) {
            preparing = true
            results = []
            let sources = store.searchSources
            let worker = Task.detached(priority: .userInitiated) { ProfileSearchIndex.prepare(sources) }
            let snapshot = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
            guard !Task.isCancelled else { return }
            documents = snapshot
            preparing = false
            revision &+= 1
        }
        .task(id: ProfileSearchRequest(query: query, regex: useRegex, revision: revision)) {
            results = []
            patternError = nil
            searching = false
            guard !preparing && !query.isEmpty else { return }
            searching = true
            do { try await Task.sleep(nanoseconds: 150_000_000) } catch { return }
            let expression: NSRegularExpression?
            do {
                expression = useRegex ? try NSRegularExpression(pattern: query, options: [.caseInsensitive]) : nil
            } catch {
                patternError = "Invalid regular expression: \(error.localizedDescription)"
                searching = false
                return
            }
            let snapshot = documents
            let term = query
            let worker = Task.detached(priority: .userInitiated) {
                ProfileSearchIndex.matches(term, prepared: snapshot, regex: expression)
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
