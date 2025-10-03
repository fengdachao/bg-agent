import SwiftUI

struct ContentView: View {
    @ObservedObject var systemInfo: SystemInfo
    @State private var isMinimized = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题栏
            HStack {
                Text("系统监控")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    isMinimized = true
                }) {
                    Image(systemName: "minus")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            
            // 系统信息显示
            VStack(spacing: 15) {
                // CPU 使用率
                SystemInfoCard(
                    title: "CPU 使用率",
                    value: String(format: "%.1f%%", systemInfo.cpuUsage),
                    progress: systemInfo.cpuUsage / 100.0,
                    color: .blue
                )
                
                // 内存使用率
                SystemInfoCard(
                    title: "内存使用率",
                    value: String(format: "%.1f%%", systemInfo.memoryUsage),
                    progress: systemInfo.memoryUsage / 100.0,
                    color: .green
                )
                
                // 内存详细信息
                HStack {
                    VStack(alignment: .leading) {
                        Text("已用内存")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(systemInfo.formatBytes(systemInfo.usedMemory))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("总内存")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(systemInfo.formatBytes(systemInfo.totalMemory))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .padding(.horizontal)
                
                // 网络使用情况
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("网络下载")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(systemInfo.formatSpeed(systemInfo.networkIn))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("网络上传")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(systemInfo.formatSpeed(systemInfo.networkOut))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .frame(width: 300, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}

struct SystemInfoCard: View {
    let title: String
    let value: String
    let progress: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 8)
                        .cornerRadius(4)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

#Preview {
    ContentView(systemInfo: SystemInfo())
}