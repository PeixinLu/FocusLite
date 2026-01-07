import Foundation

final class AppIndexWatcher {
    private let roots: [URL]
    private let debounceInterval: TimeInterval
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "focuslite.appindex.watcher", qos: .utility)
    private var sources: [DispatchSourceFileSystemObject] = []
    private var pendingWork: DispatchWorkItem?

    init(roots: [URL], debounceInterval: TimeInterval = 1.0, onChange: @escaping () -> Void) {
        self.roots = roots
        self.debounceInterval = debounceInterval
        self.onChange = onChange
    }

    func start() {
        stop()
        let fileManager = FileManager.default
        for root in roots where fileManager.fileExists(atPath: root.path) {
            let fd = open(root.path, O_EVTONLY)
            guard fd >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .delete, .rename, .attrib, .extend],
                queue: queue
            )
            source.setEventHandler { [weak self] in
                self?.scheduleChange()
            }
            source.setCancelHandler {
                close(fd)
            }
            source.resume()
            sources.append(source)
        }
    }

    func stop() {
        pendingWork?.cancel()
        pendingWork = nil
        sources.forEach { $0.cancel() }
        sources.removeAll()
    }

    private func scheduleChange() {
        pendingWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onChange()
        }
        pendingWork = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    deinit {
        stop()
    }
}
