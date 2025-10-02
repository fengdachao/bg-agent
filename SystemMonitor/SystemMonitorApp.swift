import SwiftUI

@main
struct SystemMonitorApp: App {
    @StateObject private var statusBarManager = StatusBarManager()
    @State private var isMainWindowVisible = true
    
    var body: some Scene {
        // 主窗口
        WindowGroup {
            ContentView()
                .onAppear {
                    setupWindowBehavior()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .windowArrangement) {
                Button("最小化到状态栏") {
                    minimizeToStatusBar()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            }
        }
        
        // 状态栏菜单
        MenuBarExtra("System Monitor", systemImage: "chart.bar.fill") {
            Button("显示主窗口") {
                showMainWindow()
            }
            .keyboardShortcut("w", modifiers: [.command])
            
            Divider()
            
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
        .menuBarExtraStyle(.window)
    }
    
    private func setupWindowBehavior() {
        // 设置窗口关闭行为
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let window = notification.object as? NSWindow,
               window.isMainWindow {
                minimizeToStatusBar()
            }
        }
    }
    
    private func minimizeToStatusBar() {
        // 隐藏主窗口
        if let window = NSApplication.shared.windows.first {
            window.orderOut(nil)
        }
        isMainWindowVisible = false
    }
    
    private func showMainWindow() {
        // 显示主窗口
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        isMainWindowVisible = true
    }
}

// 窗口控制器扩展
extension NSWindow {
    var isMainWindow: Bool {
        return self.title == "SystemMonitor" || self.contentView?.className.contains("ContentView") == true
    }
}

// 应用程序生命周期管理
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置应用程序不在 Dock 中显示（可选）
        // NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // 如果没有可见窗口，显示主窗口
            if let window = sender.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 清理资源
    }
}