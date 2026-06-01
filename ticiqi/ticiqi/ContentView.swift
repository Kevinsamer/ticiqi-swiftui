//  Root view — manages app-level engine, server, store, and network monitor
//  ticiqi
//

import SwiftUI

struct ContentView: View {
    @State private var engine = PrompterEngine()
    @State private var serverManager = PrompterServerManager()
    @State private var store = ScriptStore()
    @State private var networkMonitor = NetworkMonitor()

    var body: some View {
        ScriptLibraryView(engine: engine, serverManager: serverManager, store: store)
            .preferredColorScheme(.dark)
            .onAppear {
                store.loadAll()
                serverManager.onWebUpload = { title, content in
                    let script = store.importFromContent(content, title: title)
                    let doc = store.toDocument(script)
                    engine.load(document: doc)
                }
                networkMonitor.start()
                serverManager.monitorNetwork(networkMonitor)
                let settings = PrompterSettings.load()
                if settings.autoStartServer {
                    serverManager.start(engine: engine)
                }
            }
            .onDisappear {
                serverManager.shutdown()
                engine.shutdown()
            }
    }
}
