//  WebSocket infrastructure — broadcaster, per-connection handler, command parser
//  ticiqi
//

import Foundation
import FlyingFox

// MARK: - Control command

enum ControlCommand {
    case play
    case pause
    case speed(Double)
    case fontSize(Double)
    case updateText(String)
    case seek(Double)
    case mirror
    case focusLine
    case scrollDirection
    case ping
}

// MARK: - Thread-safe message receiver

actor MessageReceiver {
    private var handler: (@MainActor (String) -> Void)?

    func setHandler(_ handler: @escaping @MainActor (String) -> Void) {
        self.handler = handler
    }

    func receive(_ text: String) async {
        await handler?(text)
    }
}

// MARK: - Multi-client broadcaster

actor WebSocketBroadcaster {
    private var continuations: [UUID: AsyncStream<WSMessage>.Continuation] = [:]
    private var clients: [UUID: ClientInfo] = [:]
    private var heartbeatTask: Task<Void, Never>?
    private let broadcastStream: AsyncStream<String>
    private let broadcastContinuation: AsyncStream<String>.Continuation
    private var broadcastConsumerStarted = false
    var onCountChange: (@MainActor (Int) -> Void)?

    private let staleTimeout: TimeInterval = 10
    private let cleanupInterval: TimeInterval = 5

    var count: Int { clients.count }

    init() {
        let (stream, continuation) = AsyncStream<String>.makeStream()
        self.broadcastStream = stream
        self.broadcastContinuation = continuation
    }

    private func startBroadcastConsumerIfNeeded() {
        guard !broadcastConsumerStarted else { return }
        broadcastConsumerStarted = true
        Task { [weak self] in
            guard let self else { return }
            for await message in self.broadcastStream {
                await self.doBroadcast(message)
            }
        }
    }

    private func startHeartbeatIfNeeded() {
        guard heartbeatTask == nil else { return }
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.cleanupInterval ?? 5))
                guard let self else { return }
                await self.cleanupStaleClients()
                if await self.clients.isEmpty {
                    await self.stopHeartbeat()
                }
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    func register() -> (UUID, AsyncStream<WSMessage>) {
        let id = UUID()
        let (stream, continuation) = AsyncStream<WSMessage>.makeStream()
        continuations[id] = continuation
        clients[id] = ClientInfo(id: id, connectedAt: .now, lastSeenAt: .now)
        startHeartbeatIfNeeded()
        notifyCountChange()
        return (id, stream)
    }

    func unregister(id: UUID) {
        continuations[id]?.finish()
        continuations.removeValue(forKey: id)
        clients.removeValue(forKey: id)
        notifyCountChange()
    }

    func touchClient(id: UUID) {
        clients[id]?.lastSeenAt = .now
    }

    func broadcast(_ message: String) {
        startBroadcastConsumerIfNeeded()
        broadcastContinuation.yield(message)
    }

    private func doBroadcast(_ message: String) {
        let msg = WSMessage.text(message)
        for continuation in continuations.values {
            continuation.yield(msg)
        }
    }

    func setOnCountChange(_ handler: @escaping @MainActor (Int) -> Void) {
        onCountChange = handler
    }

    private func notifyCountChange() {
        let c = clients.count
        Task { @MainActor [onCountChange] in
            onCountChange?(c)
        }
    }

    private func cleanupStaleClients() {
        let now = Date()
        let stale = clients.filter {
            now.timeIntervalSince($0.value.lastSeenAt) > staleTimeout
        }
        for (id, _) in stale {
            unregister(id: id)
        }
    }
}

// MARK: - Per-connection WS handler (Sendable-safe)

final class PerConnectionHandler: WSMessageHandler, Sendable {
    private let receiver: MessageReceiver
    private let broadcaster: WebSocketBroadcaster

    init(receiver: MessageReceiver, broadcaster: WebSocketBroadcaster) {
        self.receiver = receiver
        self.broadcaster = broadcaster
    }

    func makeMessages(for client: AsyncStream<WSMessage>) async throws -> AsyncStream<WSMessage> {
        let (id, outgoing) = await broadcaster.register()

        Task { [receiver, broadcaster, id] in
            for await message in client {
                switch message {
                case .text(let text):
                    await broadcaster.touchClient(id: id)
                    await receiver.receive(text)
                case .data, .close:
                    break
                }
            }
            await broadcaster.unregister(id: id)
        }

        return outgoing
    }
}

// MARK: - JSON command parser

enum CommandParser {
    static func parse(from json: String) -> ControlCommand? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = obj["action"] as? String else { return nil }

        switch action {
        case "ping":              return .ping
        case "play":              return .play
        case "pause":             return .pause
        case "mirror":            return .mirror
        case "focusLine":         return .focusLine
        case "scrollDirection":   return .scrollDirection
        case "speed":
            guard let v = obj["value"] as? Double else { return nil }
            return .speed(v)
        case "fontSize":
            guard let v = obj["value"] as? Double else { return nil }
            return .fontSize(v)
        case "updateText":
            guard let v = obj["value"] as? String, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return .updateText(v)
        case "seek":
            guard let v = obj["value"] as? Double else { return nil }
            return .seek(max(0, min(1, v)))
        default:
            return nil
        }
    }
}
