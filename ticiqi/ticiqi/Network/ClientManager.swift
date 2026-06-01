//  Client info model — lightweight connection metadata with heartbeat tracking
//  ticiqi
//

import Foundation

struct ClientInfo: Identifiable {
    let id: UUID
    let connectedAt: Date
    var lastSeenAt: Date
}
