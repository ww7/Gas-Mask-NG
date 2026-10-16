import AppKit
import SwiftUI

@objc final class PreferencesPresenter: NSObject {
    private static var window: NSWindow?

    @objc static func showPreferences() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let tabVC = FittingPreferencesTabController()
        tabVC.tabStyle = .toolbar

        func makeTab<V: View>(label: String, symbolName: String, rootView: V) -> NSTabViewItem {
            let hc = NSHostingController(rootView: rootView
                // Center the content block; controls retain their own alignment.
                .frame(width: 480, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .fixedSize(horizontal: false, vertical: true))
            hc.view.layoutSubtreeIfNeeded()
            hc.preferredContentSize = NSSize(width: 536, height: ceil(hc.view.fittingSize.height))
            let item = NSTabViewItem(viewController: hc)
            item.label = label
            item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label)
            return item
        }

        tabVC.addTabViewItem(makeTab(label: "General", symbolName: "gearshape", rootView: GeneralTab()))
        tabVC.addTabViewItem(makeTab(label: "Editor", symbolName: "square.and.pencil", rootView: EditorTab()))
        tabVC.addTabViewItem(makeTab(label: "Remote", symbolName: "globe", rootView: RemoteTab()))
        tabVC.addTabViewItem(makeTab(label: "Hotkeys", symbolName: "command.square.fill", rootView: HotkeysTab()))
        tabVC.addTabViewItem(makeTab(label: "Update", symbolName: "arrow.triangle.2.circlepath", rootView: UpdateTab()))

        let w = NSWindow(contentViewController: tabVC)
        w.styleMask = [.titled, .closable]
        w.toolbarStyle = .preference
        w.title = tabVC.tabViewItems.first?.label ?? "Settings"
        w.setFrameAutosaveName("PreferencesWindow")
        tabVC.resizeToSelectedTab()

        // Keep the window alive after close so it can be reopened
        w.isReleasedWhenClosed = false

        window = w
        w.center()
        w.makeKeyAndOrderFront(nil)
    }
}

/// Keep the window's top edge stationary while fitting each tab's natural height.
private final class FittingPreferencesTabController: NSTabViewController {
    override func viewDidAppear() {
        super.viewDidAppear()
        resizeToSelectedTab()
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        resizeToSelectedTab()
    }

    func resizeToSelectedTab() {
        guard isViewLoaded, let window = view.window,
              tabViewItems.indices.contains(selectedTabViewItemIndex),
              let child = tabViewItems[selectedTabViewItemIndex].viewController else { return }
        let padding = max(0, tabView.bounds.height - tabView.contentRect.height)
        let size = NSSize(width: child.preferredContentSize.width,
                          height: child.preferredContentSize.height + padding)
        let desired = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        var frame = window.frame
        frame.origin.y += frame.height - desired.height
        frame.size = desired.size
        if frame != window.frame { window.setFrame(frame, display: true) }
    }
}
