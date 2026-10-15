import SwiftUI

struct EditorView: View {
    @StateObject private var store: HostsDataStore

    init(store: HostsDataStore = HostsDataStore()) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                SidebarView(store: store)
                    .overlay {
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Divider()
                        }
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
                    .navigationSplitViewColumnWidth(min: 140, ideal: 160, max: 300)
            } detail: {
                ContentView(store: store)
            }
            StatusBarView(store: store)
        }
        .frame(minWidth: 400, minHeight: 300)
        .toolbar { EditorToolbar(store: store) }
        .sheet(isPresented: $store.showingGlobalSearch) { ProfileSearchView(store: store) }
        .sheet(isPresented: $store.showingHelp) { EditorHelpView() }
    }
}
