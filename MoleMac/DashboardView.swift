import SwiftUI

struct DashboardView: View {
    @State private var metrics: MetricsSnapshot?
    @State private var isLoading = true
    @State private var notInstalled = false

    private let runner = MoleRunner()
    private let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if isLoading && metrics == nil {
                loadingView
            } else if notInstalled {
                notInstalledView
            } else if let m = metrics {
                metricsContent(m)
            }
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Button(action: { fetchMetrics() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh")
                }
            }
        }
        .onAppear { fetchMetrics() }
        .onReceive(timer) { _ in fetchMetrics() }
    }

    // MARK: - Sub-views

    var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading system data…")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var notInstalledView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundColor(.orange)
            Text("Mole is not installed")
                .font(.title2.bold())
            Text("Install Mole to use this app.")
                .foregroundColor(.secondary)
            Button("Install Mole") {
                NSWorkspace.shared.open(URL(string: "https://github.com/tw93/Mole")!)
            }
            .buttonStyle(.borderedProminent)
            Text("curl -fsSL https://raw.githubusercontent.com/tw93/Mole/main/install.sh | sh")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    func metricsContent(_ m: MetricsSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Health badge
                HStack {
                    Spacer()
                    HealthBadge(score: m.healthScore, message: m.healthScoreMsg)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Metric cards grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                ], spacing: 14) {
                    MetricCard(
                        title: "CPU",
                        icon: "cpu",
                        color: m.cpu.usage > 80 ? .red : .blue,
                        value: String(format: "%.1f%%", m.cpu.usage),
                        detail: "Load: \(String(format: "%.2f", m.cpu.load1)) • \(m.cpu.coreCount) cores",
                        progress: m.cpu.usage / 100
                    )

                    MetricCard(
                        title: "Memory",
                        icon: "memorychip",
                        color: m.memory.usedPercent > 85 ? .red : .purple,
                        value: String(format: "%.1f GB", m.memory.usedGB),
                        detail: "of \(String(format: "%.0f GB", m.memory.totalGB)) · \(m.memory.pressure)",
                        progress: m.memory.usedPercent / 100
                    )

                    if let disk = m.disks.first(where: { $0.mount == "/" }) {
                        MetricCard(
                            title: "Disk",
                            icon: "internaldrive",
                            color: disk.usedPercent > 90 ? .red : .orange,
                            value: String(format: "%.0f GB free", disk.freeGB),
                            detail: "of \(String(format: "%.0f GB", disk.totalGB)) total",
                            progress: disk.usedPercent / 100
                        )
                    }

                    if m.thermal.cpuTemp > 0 {
                        MetricCard(
                            title: "Temperature",
                            icon: "thermometer.medium",
                            color: m.thermal.cpuTemp > 85 ? .red : m.thermal.cpuTemp > 70 ? .orange : .green,
                            value: String(format: "%.0f°C", m.thermal.cpuTemp),
                            detail: m.thermal.fanCount > 0 ? "Fan: \(m.thermal.fanSpeed) RPM" : "Fanless",
                            progress: min(m.thermal.cpuTemp / 100, 1.0)
                        )
                    }

                    if let battery = m.batteries.first {
                        MetricCard(
                            title: "Battery",
                            icon: batteryIcon(battery.percent),
                            color: battery.percent < 20 ? .red : .green,
                            value: String(format: "%.0f%%", battery.percent),
                            detail: battery.status + (battery.timeLeft.isEmpty ? "" : " · \(battery.timeLeft)"),
                            progress: battery.percent / 100
                        )
                    }

                    if let net = m.network.first(where: { $0.rxRateMBs > 0 || $0.txRateMBs > 0 || !$0.ip.isEmpty }) {
                        MetricCard(
                            title: "Network",
                            icon: "network",
                            color: .cyan,
                            value: net.ip.isEmpty ? net.name : net.ip,
                            detail: String(format: "↓ %.1f  ↑ %.1f MB/s", net.rxRateMBs, net.txRateMBs),
                            progress: nil
                        )
                    }
                }
                .padding(.horizontal, 20)

                // Hardware info
                HardwareInfoRow(hardware: m.hardware, uptime: m.uptime, procs: m.procs)
                    .padding(.horizontal, 20)

                // GPU (if present)
                if let gpu = m.gpu.first, gpu.coreCount > 0 {
                    GPURow(gpu: gpu)
                        .padding(.horizontal, 20)
                }

                // Top processes
                if !m.topProcesses.isEmpty {
                    ProcessTable(processes: m.topProcesses)
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 20)
            }
        }
    }

    // MARK: - Data fetch

    private func fetchMetrics() {
        isLoading = true
        MoleRunner.fetchJSON(args: ["status", "--json"]) { data in
            isLoading = false
            guard let data else {
                notInstalled = true
                return
            }
            if let m = MoleRunner.decodeMetrics(from: data) {
                metrics = m
                notInstalled = false
            }
        }
    }

    private func batteryIcon(_ pct: Double) -> String {
        switch pct {
        case 75...: return "battery.100"
        case 50...: return "battery.75"
        case 25...: return "battery.25"
        default:    return "battery.0"
        }
    }
}

// MARK: - Reusable Cards

struct MetricCard: View {
    let title: String
    let icon: String
    let color: Color
    let value: String
    let detail: String
    let progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            if let p = progress {
                ProgressView(value: p)
                    .tint(p > 0.9 ? .red : p > 0.75 ? .orange : color)
            }
        }
        .padding(14)
        .background(.background.secondary)
        .cornerRadius(12)
    }
}

struct HealthBadge: View {
    let score: Int
    let message: String

    var color: Color {
        switch score {
        case 80...: return .green
        case 60...: return .orange
        default:    return .red
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: score >= 80 ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .foregroundColor(color)
            Text("Health: \(score)/100")
                .font(.caption.bold())
                .foregroundColor(color)
            if !message.isEmpty {
                Text("· \(message)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct HardwareInfoRow: View {
    let hardware: HardwareInfo
    let uptime: String
    let procs: UInt64

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach([
                    ("Mac", hardware.model),
                    ("CPU", hardware.cpuModel),
                    ("RAM", hardware.totalRAM),
                    ("Disk", hardware.diskSize),
                    ("OS", hardware.osVersion),
                    ("Uptime", uptime),
                    ("Procs", "\(procs)"),
                ], id: \.0) { label, value in
                    HardwareCell(label: label, value: value)
                    if label != "Procs" {
                        Divider().frame(height: 32).padding(.horizontal, 12)
                    }
                }
            }
            .padding(14)
        }
        .background(.background.secondary)
        .cornerRadius(12)
    }
}

struct HardwareCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
    }
}

struct GPURow: View {
    let gpu: GPUStatus

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "gpu")
                .foregroundColor(.indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text(gpu.name)
                    .font(.caption.bold())
                Text("\(gpu.coreCount) cores")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if gpu.usage > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f%%", gpu.usage))
                        .font(.caption.bold())
                    Text("GPU load")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(.background.secondary)
        .cornerRadius(12)
    }
}

struct ProcessTable: View {
    let processes: [ProcessInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Top Processes")
                    .font(.headline)
                Spacer()
                Text("CPU")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
                Text("MEM")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, 12)

            ForEach(processes.prefix(8), id: \.name) { proc in
                HStack {
                    Text(proc.name)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.1f%%", proc.cpu))
                        .font(.caption)
                        .foregroundColor(proc.cpu > 50 ? .orange : .secondary)
                        .frame(width: 60, alignment: .trailing)
                    Text(String(format: "%.1f%%", proc.memory))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(6)
            }
        }
        .padding(14)
        .background(.background.secondary)
        .cornerRadius(12)
    }
}
