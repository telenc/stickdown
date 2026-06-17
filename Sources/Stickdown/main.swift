import AppKit

// Point d'entrée : app "accessory" (icône menubar, pas d'icône Dock).
// Le code de démarrage s'exécute sur le thread principal → on l'isole au MainActor.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    // Conserve une référence forte au delegate pendant toute la session.
    objc_setAssociatedObject(app, "postit.delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
    app.run()
}
