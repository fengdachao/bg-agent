import Foundation
import SwiftUI
import SystemConfiguration

// 系统监控数据模型
final class SystemInfo: ObservableObject {
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
    
    // CPU monitoring variables
    private var previousCpuInfo: host_cpu_load_info?
    private var lastCpuTime: Date = Date()
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSystemInfo()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateSystemInfo() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.updateCPUUsage()
            self?.updateMemoryUsage()
            self?.updateNetworkUsage()
        }
    }
    
    private func updateCPUUsage() {
        var cpuInfo = host_cpu_load_info()
        var numCpuInfo: mach_msg_type_number_t = UInt32(MemoryLayout<host_cpu_load_info>.size) / UInt32(MemoryLayout<integer_t>.size)
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(numCpuInfo)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &numCpuInfo)
            }
        }
        
        if result == KERN_SUCCESS {
            let now = Date()
            let timeInterval = now.timeIntervalSince(lastCpuTime)
            
            if let previous = previousCpuInfo, timeInterval > 0 {
                let userDiff = Double(cpuInfo.cpu_ticks.0 - previous.cpu_ticks.0)
                let systemDiff = Double(cpuInfo.cpu_ticks.1 - previous.cpu_ticks.1)
                let idleDiff = Double(cpuInfo.cpu_ticks.2 - previous.cpu_ticks.2)
                let niceDiff = Double(cpuInfo.cpu_ticks.3 - previous.cpu_ticks.3)
                
                let totalDiff = userDiff + systemDiff + idleDiff + niceDiff
                let usedDiff = userDiff + systemDiff + niceDiff
                
                // 确保值在合理范围内
                let cpuUsage = totalDiff > 0 ? min(max((usedDiff / totalDiff) * 100.0, 0.0), 100.0) : 0.0
                
                DispatchQueue.main.async { [weak self] in
                    self?.cpuUsage = cpuUsage
                }
            }
            
            previousCpuInfo = cpuInfo
            lastCpuTime = now
        } else {
            // 如果获取CPU信息失败，记录错误但不崩溃
            print("Failed to get CPU info: \(result)")
        }
    }
    
    private func updateMemoryUsage() {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let pageSize = UInt64(vm_page_size)
            let totalMemory = ProcessInfo.processInfo.physicalMemory
            let freeMemory = UInt64(vmStats.free_count) * pageSize
            let activeMemory = UInt64(vmStats.active_count) * pageSize
            let inactiveMemory = UInt64(vmStats.inactive_count) * pageSize
            let wiredMemory = UInt64(vmStats.wire_count) * pageSize
            let compressedMemory = UInt64(vmStats.compressor_page_count) * pageSize
            
            let usedMemory = totalMemory - freeMemory
            
            // 确保内存使用率在合理范围内
            let memoryUsage = totalMemory > 0 ? min(max(Double(usedMemory) / Double(totalMemory) * 100.0, 0.0), 100.0) : 0.0
            
            DispatchQueue.main.async { [weak self] in
                self?.totalMemory = totalMemory
                self?.usedMemory = usedMemory
                self?.memoryUsage = memoryUsage
            }
        } else {
            // 如果获取内存信息失败，记录错误但不崩溃
            print("Failed to get memory info: \(result)")
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
            
            // 检查接口是否有效
            guard let addr = interface.ifa_addr else { continue }
            let addrFamily = addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_LINK) {
                let name = String(cString: interface.ifa_name)
                // 只统计主要的网络接口，排除虚拟接口
                if (name.hasPrefix("en") || name.hasPrefix("wlan") || name.hasPrefix("bridge")) && 
                   !name.contains("lo") && !name.contains("utun") {
                    if let data = interface.ifa_data {
                        let stats = data.withMemoryRebound(to: if_data.self, capacity: 1) { $0.pointee }
                        currentIn += UInt64(stats.ifi_ibytes)
                        currentOut += UInt64(stats.ifi_obytes)
                    }
                }
            }
        }
        
        freeifaddrs(ifaddrs)
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastNetworkTime)
        
        // 确保时间间隔足够大以避免除零错误
        if timeInterval > 0.1 {
            let inDiff = currentIn > previousNetworkIn ? currentIn - previousNetworkIn : 0
            let outDiff = currentOut > previousNetworkOut ? currentOut - previousNetworkOut : 0
            
            // 确保网络速度在合理范围内
            let networkInSpeed = max(Double(inDiff) / timeInterval / 1024.0, 0.0) // KB/s
            let networkOutSpeed = max(Double(outDiff) / timeInterval / 1024.0, 0.0) // KB/s
            
            DispatchQueue.main.async { [weak self] in
                self?.networkIn = networkInSpeed
                self?.networkOut = networkOutSpeed
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