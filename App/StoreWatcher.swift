import Foundation

/// Watches the store's directory: atomic writes replace the file, so watching the file itself would go stale.
final class StoreWatcher {
    private let source: DispatchSourceFileSystemObject
    private let fd: Int32

    init?(url: URL, onChange: @escaping @MainActor () -> Void) {
        fd = open(url.deletingLastPathComponent().path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
        source.setEventHandler { MainActor.assumeIsolated { onChange() } }
        source.setCancelHandler { [fd] in close(fd) }
        source.resume()
    }

    deinit { source.cancel() }
}
