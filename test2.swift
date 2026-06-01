import Foundation
import Network

var sa = sockaddr_in()
sa.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
sa.sin_family = sa_family_t(AF_INET)
sa.sin_port = in_port_t(8080).bigEndian
sa.sin_addr.s_addr = in_addr_t(0) // INADDR_ANY
print(sa.sin_port)
