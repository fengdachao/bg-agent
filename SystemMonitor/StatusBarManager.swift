import SwiftUI
import AppKit

class StatusBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var systemInfo: SystemInfo?
    
    @Published var isMenuVisible = false
    
    init() {
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let statusItem = statusItem else { return }
        
        // 设置状态栏按钮
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "System Monitor")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
        
        // 创建弹出窗口
        setupPopover()
        
        // 初始化系统信息监控
        systemInfo = SystemInfo()
        systemInfo?.startMonitoring()
        
        // 定期更新状态栏显示
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.updateStatusBarDisplay()
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: PopoverContentView(systemInfo: systemInfo))
    }
    
    @objc private func statusBarButtonClicked() {
        guard let popover = popover, let statusItem = statusItem else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    private func updateStatusBarDisplay() {
        guard let statusItem = statusItem,
              let button = statusItem.button,
              let systemInfo = systemInfo else { return }
        
        // 创建网格图作为状态栏图标
        let gridImage = createGridImage(
            cpuUsage: systemInfo.cpuUsage,
            memoryUsage: systemInfo.memoryUsage,
            networkIn: systemInfo.networkIn,
            networkOut: systemInfo.networkOut
        )
        
        button.image = gridImage
        
        // 设置工具提示
        let tooltip = String(format: "CPU: %.1f%%\n内存: %.1f%%\n网络: ↓%.1f ↑%.1f KB/s",
                           systemInfo.cpuUsage,
                           systemInfo.memoryUsage,
                           systemInfo.networkIn,
                           systemInfo.networkOut)
        button.toolTip = tooltip
    }
    
    private func createGridImage(cpuUsage: Double, memoryUsage: Double, networkIn: Double, networkOut: Double) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // 背景
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // 绘制网格
        let gridSize = 4
        let cellSize: CGFloat = 3
        let spacing: CGFloat = 1
        
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let x = CGFloat(col) * (cellSize + spacing) + 1
                let y = CGFloat(row) * (cellSize + spacing) + 1
                let rect = NSRect(x: x, y: y, width: cellSize, height: cellSize)
                
                let index = row * gridSize + col
                let totalCells = gridSize * gridSize
                
                // 根据系统使用率决定颜色
                let cpuCells = Int((cpuUsage / 100.0) * Double(totalCells))
                let memoryCells = Int((memoryUsage / 100.0) * Double(totalCells))
                let networkCells = Int(((networkIn + networkOut) / 2000.0) * Double(totalCells))
                
                let totalActiveCells = min(cpuCells + memoryCells + networkCells, totalCells)
                
                if index < totalActiveCells {
                    // 根据使用率选择颜色
                    if index < cpuCells {
                        NSColor.systemBlue.setFill()
                    } else if index < cpuCells + memoryCells {
                        NSColor.systemGreen.setFill()
                    } else {
                        NSColor.systemOrange.setFill()
                    }
                } else {
                    NSColor.gray.withAlphaComponent(0.3).setFill()
                }
                
                rect.fill()
            }
        }
        
        image.unlockFocus()
        return image
    }
    
    func showMainWindow() {
        // 显示主窗口的逻辑
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
}

// 弹出窗口内容视图
struct PopoverContentView: View {
    @ObservedObject var systemInfo: SystemInfo?
    @StateObject private var statusBarManager = StatusBarManager()
    
    var body: some View {
        VStack(spacing: 15) {
            // 标题
            HStack {
                Text("系统监控")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            
            if let systemInfo = systemInfo {
                // 快速状态显示
                VStack(spacing: 10) {
                    HStack {
                        Text("CPU:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f%%", systemInfo.cpuUsage))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("内存:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f%%", systemInfo.memoryUsage))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("网络:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "↓%.1f ↑%.1f KB/s", systemInfo.networkIn, systemInfo.networkOut))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
                
                // 网格图显示
                VStack {
                    Text("状态图")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    DetailedGridView(
                        cpuUsage: systemInfo.cpuUsage,
                        memoryUsage: systemInfo.memoryUsage,
                        networkIn: systemInfo.networkIn,
                        networkOut: systemInfo.networkOut
                    )
                }
                
                Divider()
                
                // 操作按钮
                VStack(spacing: 8) {
                    Button("显示主窗口") {
                        statusBarManager.showMainWindow()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button("退出应用") {
                        statusBarManager.quitApplication()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                Text("正在加载系统信息...")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 280, height: 350)
    }
}