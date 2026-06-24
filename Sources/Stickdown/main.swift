import AppKit

// Point d'entrée. La politique d'activation (Dock/menubar) est ajustée par
// AppDelegate selon le réglage "Afficher dans le Dock".
// Le code de démarrage s'exécute sur le thread principal → on l'isole au MainActor.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    // Conserve une référence forte au delegate pendant toute la session.
    objc_setAssociatedObject(app, "postit.delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
    app.run()
}
