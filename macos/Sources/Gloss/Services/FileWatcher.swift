import Foundation

/// Watches a file for changes using DispatchSource and calls a handler on the main queue.
@MainActor
final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    /// Start watching a file. Calls `onChange` on the main queue when the file is modified.
    func watch(url: URL, onChange: @escaping @Sendable () -> Void) {
        stop()

        let path = url.path
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename],
            queue: .main
        )

        source.setEventHandler {
            onChange()
        }

        source.setCancelHandler { [fd = fileDescriptor] in
            close(fd)
        }

        source.resume()
        self.source = source
    }

    /// Stop watching the current file.
    func stop() {
        source?.cancel()
        source = nil
        fileDescriptor = -1
    }

    deinit {
        source?.cancel()
    }
}
