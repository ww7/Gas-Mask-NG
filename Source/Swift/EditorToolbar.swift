import SwiftUI

struct EditorToolbar: ToolbarContent {
    @ObservedObject var store: HostsDataStore

    @State private var hostsToRemove: Hosts?

    var body: some ToolbarContent {
        ToolbarItem(id: "create", placement: .navigation) {
            Menu {
                Button("Local") {
                    HostsMainController.defaultInstance()?.createNewHostsFile(nil)
                }
                Button("Remote") {
                    URLSheetPresenter.presentInWindow(nil)
                }
                Button("Combined") {
                    HostsMainController.defaultInstance()?.createCombinedHostsFile(nil)
                }
            } label: {
                Label("Create", systemImage: "plus")
            }
        }

        if #available(macOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .navigation)
        }

        ToolbarItem(id: "remove", placement: .navigation) {
            Button {
                hostsToRemove = store.selectedHosts
            } label: {
                Label("Remove", systemImage: "minus")
            }
            .disabled(!store.canRemoveFiles || store.selectedHosts == nil)
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

        if #available(macOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .navigation)
        }

        ToolbarItem(id: "update-remote", placement: .navigation) {
            Button {
                ApplicationController.defaultInstance()?.updateAndSynchronize(nil)
            } label: {
                Label("Update Remote Files", systemImage: "icloud.and.arrow.down")
            }
            .help("Update Remote Files")
            .disabled(!store.canUpdateRemoteFiles)
        }

        if #available(macOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .navigation)
        }

        ToolbarItem(id: "save", placement: .navigation) {
            Button {
                if let hosts = store.selectedHosts {
                    HostsMainController.defaultInstance()?.save(hosts)
                }
            } label: {
                Label("Save", systemImage: "arrow.down")
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(store.selectedHosts == nil || store.selectedHosts?.saved() != false)
        }

        ToolbarItem(id: "activate", placement: .navigation) {
            Button {
                if let hosts = store.selectedHosts {
                    HostsMainController.defaultInstance()?.activateHostsFile(hosts)
                }
            } label: {
                Label("Activate", systemImage: "checkmark")
            }
            .disabled(
                store.selectedHosts == nil
                || store.selectedHosts?.active() == true
                || store.selectedHosts?.exists != true
            )
        }
    }
}
