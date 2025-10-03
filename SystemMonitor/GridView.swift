import SwiftUI

struct GridView: View {
    let cpuUsage: Double
    let memoryUsage: Double
    let networkIn: Double
    let networkOut: Double
    
    private let gridSize = 4
    private let cellSize: CGFloat = 8
    private let spacing: CGFloat = 2
    
    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<gridSize, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<gridSize, id: \.self) { col in
                        GridCell(
                            isActive: isCellActive(row: row, col: col),
                            size: cellSize
                        )
                    }
                }
            }
        }
    }
    
    private func isCellActive(row: Int, col: Int) -> Bool {
        let index = row * gridSize + col
        let totalCells = gridSize * gridSize
        
        // 根据不同的指标分配网格
        let cpuCells = Int((cpuUsage / 100.0) * Double(totalCells))
        let memoryCells = Int((memoryUsage / 100.0) * Double(totalCells))
        let networkCells = Int(((networkIn + networkOut) / 1000.0) * Double(totalCells)) // 假设1000 KB/s为满值
        
        // 组合所有指标
        let totalActiveCells = min(cpuCells + memoryCells + networkCells, totalCells)
        
        return index < totalActiveCells
    }
}

struct GridCell: View {
    let isActive: Bool
    let size: CGFloat
    
    var body: some View {
        Rectangle()
            .fill(isActive ? Color.blue : Color.gray.opacity(0.3))
            .frame(width: size, height: size)
            .cornerRadius(1)
            .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

// 更详细的网格视图，分别显示不同指标
struct DetailedGridView: View {
    let cpuUsage: Double
    let memoryUsage: Double
    let networkIn: Double
    let networkOut: Double
    
    private let gridSize = 4
    private let cellSize: CGFloat = 6
    private let spacing: CGFloat = 1
    
    var body: some View {
        VStack(spacing: 2) {
            // CPU 网格 (蓝色)
            GridRow(
                usage: cpuUsage,
                color: .blue,
                gridSize: gridSize,
                cellSize: cellSize,
                spacing: spacing
            )
            
            // 内存网格 (绿色)
            GridRow(
                usage: memoryUsage,
                color: .green,
                gridSize: gridSize,
                cellSize: cellSize,
                spacing: spacing
            )
            
            // 网络网格 (橙色)
            GridRow(
                usage: min((networkIn + networkOut) / 10.0, 100.0), // 标准化网络使用率
                color: .orange,
                gridSize: gridSize,
                cellSize: cellSize,
                spacing: spacing
            )
        }
    }
}

struct GridRow: View {
    let usage: Double
    let color: Color
    let gridSize: Int
    let cellSize: CGFloat
    let spacing: CGFloat
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<gridSize, id: \.self) { index in
                Rectangle()
                    .fill(index < Int((usage / 100.0) * Double(gridSize)) ? color : Color.gray.opacity(0.2))
                    .frame(width: cellSize, height: cellSize)
                    .cornerRadius(0.5)
                    .animation(.easeInOut(duration: 0.2), value: usage)
            }
        }
    }
}

// 圆形网格视图
struct CircularGridView: View {
    let cpuUsage: Double
    let memoryUsage: Double
    let networkUsage: Double
    
    private let radius: CGFloat = 12
    private let cellCount = 16
    
    var body: some View {
        ZStack {
            // 背景圆
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                .frame(width: radius * 2, height: radius * 2)
            
            // 网格点
            ForEach(0..<cellCount, id: \.self) { index in
                let angle = Double(index) * 2 * .pi / Double(cellCount)
                let x = cos(angle) * radius
                let y = sin(angle) * radius
                
                Circle()
                    .fill(getCellColor(for: index))
                    .frame(width: 3, height: 3)
                    .offset(x: x, y: y)
                    .animation(.easeInOut(duration: 0.3), value: cpuUsage)
            }
        }
    }
    
    private func getCellColor(for index: Int) -> Color {
        let totalUsage = (cpuUsage + memoryUsage + networkUsage) / 3.0
        let activeCells = Int((totalUsage / 100.0) * Double(cellCount))
        
        return index < activeCells ? Color.blue : Color.gray.opacity(0.3)
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("网格图预览")
            .font(.headline)
        
        HStack(spacing: 20) {
            VStack {
                Text("基础网格")
                    .font(.caption)
                GridView(
                    cpuUsage: 75.0,
                    memoryUsage: 60.0,
                    networkIn: 500.0,
                    networkOut: 200.0
                )
            }
            
            VStack {
                Text("详细网格")
                    .font(.caption)
                DetailedGridView(
                    cpuUsage: 75.0,
                    memoryUsage: 60.0,
                    networkIn: 500.0,
                    networkOut: 200.0
                )
            }
            
            VStack {
                Text("圆形网格")
                    .font(.caption)
                CircularGridView(
                    cpuUsage: 75.0,
                    memoryUsage: 60.0,
                    networkUsage: 35.0
                )
            }
        }
    }
    .padding()
}