//  HTTP + WebSocket server manager — FlyingFox lifecycle, static files, state broadcast
//  ticiqi
//

import Foundation
import Network
import FlyingFox
import FlyingSocks

@MainActor
final class PrompterServerManager {
    private var server: HTTPServer?
    private var serverTask: Task<Void, Never>?
    private var netService: NetService?
    private var permissionTrigger: NWListener?
    private let receiver = MessageReceiver()
    private let broadcaster = WebSocketBroadcaster()
    private weak var engine: PrompterEngine?

    /// Called when web console uploads text — saves to ScriptStore and loads into engine.
    var onWebUpload: ((String, String) -> Void)?

    /// Current app page — broadcast to web clients for context-aware UI.
    var currentPage: String = "library" {
        didSet { Task { await broadcaster.broadcast(buildPageMessage()) } }
    }

    /// Tracks whether content has changed since last broadcast.
    private var contentDirty = true

    /// Client count observable for UI display.
    private(set) var clientCount: Int = 0

    static let bonjourName = "MyTeleprompter"
    static let bonjourHost = "\(bonjourName).local"
    static let port = 8080

    var ipURL: String? {
        guard let ip = LocalIPAddress.current() else { return nil }
        return "http://\(ip):\(Self.port)"
    }

    // MARK: - Lifecycle

    deinit {
        // Synchronous safety net — cancel task, ARC handles the rest
        serverTask?.cancel()
    }

    func shutdown() {
        teardownServer()
    }

    var isRunning: Bool { server != nil }

    func start(engine: PrompterEngine) {
        self.engine = engine

        setupCommandReceiver()
        setupBroadcast(from: engine)
        setupClientCountObserver()

        triggerNetworkPermission()

        guard !isRunning else { return }

        let srv = HTTPServer(address: sockaddr_in.inet(port: 8080))
        server = srv

        serverTask = Task { [weak self] in
            guard let self else { return }
            await self.configureRoutes(on: srv)
            do {
                try await srv.run()
            } catch {
                print("[ticiqi] Server error: \(error)")
            }
        }
    }

    func stop() { teardownServer() }

    // MARK: - Network monitoring

    func monitorNetwork(_ monitor: NetworkMonitor) {
        monitor.onStatusChange = { [weak self] connected in
            guard let self else { return }
            if !connected {
                print("[ticiqi] WiFi lost — stopping server")
                self.teardownServer()
            } else if let engine = self.engine {
                print("[ticiqi] WiFi restored — restarting server")
                self.start(engine: engine)
            }
        }
    }

    private func teardownServer() {
        serverTask?.cancel()
        permissionTrigger?.cancel()
        netService?.stop()
        Task { await server?.stop() }
        permissionTrigger = nil
        netService = nil
        server = nil
        serverTask = nil
        engine?.onStateBroadcast = nil
    }

    // MARK: - Network permission trigger

    private func triggerNetworkPermission() {
        do {
            let listener = try NWListener(using: .tcp, on: 0)
            permissionTrigger = listener
            listener.newConnectionHandler = { conn in conn.cancel() }
            listener.stateUpdateHandler = { [weak self] state in
                if case .ready = state {
                    listener.cancel()
                    MainActor.assumeIsolated { self?.permissionTrigger = nil }
                }
            }
            listener.start(queue: .main)
        } catch {
            print("[ticiqi] Permission trigger error: \(error)")
        }

        let conn = NWConnection(host: "224.0.0.251", port: .init(rawValue: 5353)!, using: .udp)
        conn.stateUpdateHandler = { state in
            if case .ready = state { conn.cancel() }
            if case .failed = state { conn.cancel() }
        }
        conn.start(queue: .main)

        let service = NetService(domain: "local.", type: "_http._tcp.", name: Self.bonjourName, port: Int32(Self.port))
        netService = service
        service.publish()
    }

    // MARK: - Route configuration

    private func configureRoutes(on srv: HTTPServer) async {
        let indexResponse = fileResponse("index.html", mime: "text/html; charset=utf-8")
            ?? HTTPResponse(statusCode: HTTPStatusCode.notFound)
        let jsResponse = fileResponse("app.js", mime: "application/javascript; charset=utf-8")
            ?? HTTPResponse(statusCode: HTTPStatusCode.notFound)
        let cssResponse = fileResponse("style.css", mime: "text/css; charset=utf-8")
            ?? HTTPResponse(statusCode: HTTPStatusCode.notFound)

        await srv.appendRoute("/", for: [.GET]) { _ in indexResponse }
        await srv.appendRoute("/app.js", for: [.GET]) { _ in jsResponse }
        await srv.appendRoute("/style.css", for: [.GET]) { _ in cssResponse }

        let wsHandler = PerConnectionHandler(receiver: receiver, broadcaster: broadcaster)
        let msgHandler = MessageFrameWSHandler(handler: wsHandler)
        let httpHandler = WebSocketHTTPHandler(handler: msgHandler)
        await srv.appendRoute("/ws", for: [.GET], to: httpHandler)

        // File upload — saves to ScriptStore and loads into engine
        await srv.appendRoute("/upload", for: [.POST]) { [weak self] request in
            guard let self else {
                return HTTPResponse(statusCode: HTTPStatusCode.internalServerError)
            }
            let body: Data
            do {
                body = try await request.bodyData
            } catch {
                return HTTPResponse(statusCode: HTTPStatusCode.badRequest)
            }
            guard let text = String(data: body, encoding: .utf8),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return HTTPResponse(statusCode: HTTPStatusCode.badRequest)
            }
            await MainActor.run {
                self.onWebUpload?("Web 上传文稿", text)
                self.contentDirty = true
            }
            return HTTPResponse(statusCode: HTTPStatusCode.ok, body: "OK".data(using: .utf8)!)
        }
    }

    // MARK: - Command receive

    private func setupCommandReceiver() {
        Task {
            await receiver.setHandler { [weak self] text in
                guard let self, let cmd = CommandParser.parse(from: text) else { return }
                Task { await self.handleCommand(cmd) }
            }
        }
    }

    // MARK: - Command dispatch

    private func handleCommand(_ cmd: ControlCommand) async {
        guard let engine else { return }
        switch cmd {
        case .play:
            engine.play()
        case .pause:
            engine.pause()
        case .speed(let v):
            engine.updateSpeed(CGFloat(v))
        case .fontSize(let v):
            engine.updateFontSize(CGFloat(v))
        case .seek(let v):
            engine.seek(to: v)
        case .mirror:
            engine.toggleMirror()
        case .focusLine:
            engine.toggleFocusLine()
        case .scrollDirection:
            engine.toggleScrollDirection()
        case .ping:
            broadcastSnapshot(engine.buildSnapshot())
        case .updateText(let v):
            await MainActor.run {
                self.onWebUpload?("Web 更新文稿", v)
                self.contentDirty = true
            }
        }
    }

    // MARK: - State broadcast

    private func setupBroadcast(from engine: PrompterEngine) {
        engine.onStateBroadcast = { [weak self] snapshot in
            self?.broadcastSnapshot(snapshot)
        }
    }

    private func setupClientCountObserver() {
        Task {
            await broadcaster.setOnCountChange { [weak self] count in
                self?.clientCount = count
            }
        }
    }

    private func broadcastSnapshot(_ snapshot: StateSnapshot) {
        var payload = snapshot
        if !contentDirty {
            payload.content = ""
        } else {
            contentDirty = false
        }
        payload.clientCount = clientCount
        payload.currentPage = currentPage

        guard let data = try? JSONEncoder().encode(payload),
              let text = String(data: data, encoding: .utf8) else { return }
        Task { await broadcaster.broadcast(text) }
    }

    private func buildPageMessage() -> String {
        let msg = ["currentPage": currentPage]
        return (try? String(data: JSONEncoder().encode(msg), encoding: .utf8)) ?? "{}"
    }
}

// MARK: - File loading

private func fileResponse(_ name: String, mime: String) -> HTTPResponse? {
    let parts = name.components(separatedBy: ".")
    guard parts.count == 2,
          let url = Bundle.main.url(forResource: parts[0], withExtension: parts[1]),
          let data = try? Data(contentsOf: url) else { return nil }
    return HTTPResponse(
        statusCode: HTTPStatusCode.ok,
        headers: [HTTPHeader.contentType: mime],
        body: data
    )
}
