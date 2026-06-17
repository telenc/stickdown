import Foundation

/// Surveille un fichier et appelle `onChange` quand il est modifié sur le disque
/// (par Obsidian, iCloud, etc.). Se ré-arme automatiquement après un remplacement de fichier.
final class FileWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        start()
    }

    private func start() {
        fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete, .attrib],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = self.source?.data ?? []
            // Beaucoup d'éditeurs remplacent le fichier : on se ré-arme.
            if flags.contains(.delete) || flags.contains(.rename) {
                self.stop()
                // Laisse le temps au nouveau fichier d'apparaître.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.start()
                    self?.onChange()
                }
            } else {
                self.onChange()
            }
        }
        src.setCancelHandler { [weak self] in
            if let fd = self?.fd, fd >= 0 { close(fd) }
            self?.fd = -1
        }
        source = src
        src.resume()
    }

    private func stop() {
        source?.cancel()
        source = nil
    }

    deinit { stop() }
}
