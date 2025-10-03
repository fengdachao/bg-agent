import Foundation
import SwiftUI
import SystemConfiguration

// 系统监控数据模型
struct SystemInfo: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var networkIn: Double = 0.0
    @Published var networkOut: Double = 0.0
    @Published var totalMemory: UInt64 = 0
    @Published var usedMemory: UInt64 = 0
    
    private var timer: Timer?
    private var previousNetworkIn: UInt64 = 0
    private var previousNetworkOut: UInt64 = 0
    private var lastNetworkTime: Date = Date()
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateSystemInfo()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateSystemInfo() {
        updateCPUUsage()
        updateMemoryUsage()
        updateNetworkUsage()
    }
    
    private func updateCPUUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let cpuInfo = host_cpu_load_info()
            var numCpuInfo: mach_msg_type_number_t = UInt32(MemoryLayout<host_cpu_load_info>.size) / UInt32(MemoryLayout<integer_t>.size)
            let result: kern_return_t = withUnsafeMutablePointer(to: &cpuInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(numCpuInfo)) {
                    host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &numCpuInfo)
                }
            }
            
            if result == KERN_SUCCESS {
                let user = Double(cpuInfo.cpu_ticks.0)
                let system = Double(cpuInfo.cpu_ticks.1)
                let idle = Double(cpuInfo.cpu_ticks.2)
                let nice = Double(cpuInfo.cpu_ticks.3)
                
                let total = user + system + idle + nice
                let used = user + system + nice
                
                DispatchQueue.main.async {
                    self.cpuUsage = total > 0 ? (used / total) * 100.0 : 0.0
                }
            }
        }
    }
    
    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let totalMemory = ProcessInfo.processInfo.physicalMemory
            let usedMemory = info.resident_size
            
            DispatchQueue.main.async {
                self.totalMemory = totalMemory
                self.usedMemory = usedMemory
                self.memoryUsage = Double(usedMemory) / Double(totalMemory) * 100.0
            }
        }
    }
    
    private func updateNetworkUsage() {
        // 获取网络接口统计信息
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrs) == 0 else { return }
        
        var currentIn: UInt64 = 0
        var currentOut: UInt64 = 0
        
        var ptr = ifaddrs
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            guard let interface = ptr?.pointee else { continue }
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_LINK) {
                let name = String(cString: interface.ifa_name)
                if name.hasPrefix("en") || name.hasPrefix("wlan") || name.hasPrefix("bridge") {
                    if let data = interface.ifa_data {
                        let stats = data.withMemoryRebound(to: if_data.self, capacity: 1) { $0.pointee }
                        currentIn += stats.ifi_ibytes
                        currentOut += stats.ifi_obytes
                    }
                }
            }
        }
        
        freeifaddrs(ifaddrs)
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastNetworkTime)
        
        if timeInterval > 0 {
            let inDiff = currentIn - previousNetworkIn
            let outDiff = currentOut - previousNetworkOut
            
            DispatchQueue.main.async {
                self.networkIn = Double(inDiff) / timeInterval / 1024.0 // KB/s
                self.networkOut = Double(outDiff) / timeInterval / 1024.0 // KB/s
            }
        }
        
        previousNetworkIn = currentIn
        previousNetworkOut = currentOut
        lastNetworkTime = now
    }
}

// 格式化工具
extension SystemInfo {
    func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    func formatSpeed(_ speed: Double) -> String {
        if speed < 1024 {
            return String(format: "%.1f KB/s", speed)
        } else {
            return String(format: "%.1f MB/s", speed / 1024.0)
        }
    }
}