//  Local IP address utility — returns Wi-Fi IPv4 for display in control panel
//  ticiqi
//

import Foundation
import Network

enum LocalIPAddress {

    static func current() -> String? {
        var addr: String?

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(first) }

        var ptr = first
        while true {
            let flags = Int32(ptr.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_RUNNING) != 0 else {
                ptr = ptr.pointee.ifa_next!
                continue
            }

            let name = String(cString: ptr.pointee.ifa_name)
            guard name == "en0" else {
                guard ptr.pointee.ifa_next != nil else { break }
                ptr = ptr.pointee.ifa_next!
                continue
            }

            guard let sa = ptr.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) else {
                guard ptr.pointee.ifa_next != nil else { break }
                ptr = ptr.pointee.ifa_next!
                continue
            }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(sa, socklen_t(sa.pointee.sa_len),
                        &hostname, socklen_t(hostname.count),
                        nil, 0, NI_NUMERICHOST)
            addr = String(cString: hostname)
            break
        }

        return addr
    }
}
