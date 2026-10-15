import SwiftUI

struct ContentView: View {
    @ObservedObject var store: HostsDataStore

    var body: some View {
        HSplitView {
            HostsTextViewRepresentable(
                selectedHosts: store.selectedHosts,
                contentToken: store.rowRefreshToken,
                focusRequest: store.editorFocusRequest,
                onTextChange: { [weak store] newText in
                    store?.selectedHosts?.setContents(newText)
                }
            )
            .clipped()
            .frame(minWidth: 80, maxWidth: .infinity, maxHeight: .infinity)
            if store.selectedHosts is CombinedHosts {
                CombinedHostsPickerView(store: store)
                    .frame(minWidth: 160, idealWidth: 200, maxWidth: 240, maxHeight: .infinity)
            }
        }
    }
}
