//  Network connectivity monitor — observes WiFi status via NWPathMonitor
//  ticiqi
//

import Foundation
import Network

final class NetworkMonitor {
    private(set) var isConnected = true
    var onStatusChange: ((Bool) -> Void)?

    private let monitor = NWPathMonitor()

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = (path.status == .satisfied)
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? true
                self?.isConnected = connected
                if wasConnected != connected {
                    self?.onStatusChange?(connected)
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor", qos: .background))
    }

    func stop() {
        monitor.cancel()
    }
}
