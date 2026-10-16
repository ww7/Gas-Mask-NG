import Foundation
import Darwin

/// Native vnode watching on the model's main queue. Each source owns its fd
/// until its cancellation handler runs; no borrowed C pointer crosses threads.
/// Reopen after every event so atomic replacement follows the new inode.
@objc final class SystemHostsWatcher: NSObject {
    private let path: String
    private let changed: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var generation = 0
    private var stopped = false

    @objc init(path: String, changed: @escaping () -> Void) {
        self.path = path
        self.changed = changed
        super.init()
        arm()
    }

    deinit { source?.cancel() }

    @objc func stop() {
        stopped = true
        generation += 1
        source?.cancel()
        source = nil
    }

    private func arm() {
        precondition(Thread.isMainThread)
        guard !stopped else { return }
        generation += 1
        let current = generation
        source?.cancel()
        source = nil
        var fd = open(path, O_EVTONLY | O_CLOEXEC | O_NOFOLLOW)
        if fd < 0 {
            // The file may be temporarily absent during an external replacement.
            fd = open((path as NSString).deletingLastPathComponent, O_EVTONLY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard fd >= 0 else { return }
        let ownedFD = fd
        let watcher = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .revoke], queue: .main)
        watcher.setEventHandler { [weak self] in
            guard let self, !self.stopped, self.generation == current else { return }
            self.arm()
            self.changed()
        }
        watcher.setCancelHandler { close(ownedFD) }
        source = watcher
        watcher.resume()
    }
}
