import SwiftUI

struct StatusView: View {
    @State private var metrics: MetricsSnapshot?
    @State private var isLoading = true
    @State private var notInstalled = false

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if isLoading && metrics == nil {
                ProgressView("Collecting metrics…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if notInstalled {
                installPrompt
            } else if let m = metrics {
                metricsScroll(m)
            }
        }
        .navigationTitle("Status")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 4) {
                    if isLoading {
                        ProgressView().controlSize(.small)
                    }
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Live")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear { fetch() }
        .onReceive(timer) { _ in fetch() }
    }

    // MARK: - Main scroll

    func metricsScroll(_ m: MetricsSnapshot) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                // CPU + Memory row
                HStack(spacing: 14) {
                    GaugeCard(
                        title: "CPU",
                        value: m.cpu.usage / 100,
                        valueLabel: String(format: "%.1f%%", m.cpu.usage),
                        subtitle: "Load \(String(format: "%.2f · %.2f · %.2f", m.cpu.load1, m.cpu.load5, m.cpu.load15))",
                        color: m.cpu.usage > 80 ? .red : .blue
                    )
                    GaugeCard(
                        title: "Memory",
                        value: m.memory.usedPercent / 100,
                        valueLabel: String(format: "%.1f%%", m.memory.usedPercent),
                        subtitle: "\(String(format: "%.1f", m.memory.usedGB)) / \(String(format: "%.0f", m.memory.totalGB)) GB · \(m.memory.pressure)",
                        color: m.memory.usedPercent > 80 ? .red : .purple
                    )
                }

                // Disks
                if !m.disks.isEmpty {
                    SectionCard(title: "Disks", icon: "internaldrive") {
                        ForEach(m.disks, id: \.mount) { disk in
                            DiskRow(disk: disk)
                        }
                    }
                }

                // Network
                let activeNets = m.network.filter { !$0.ip.isEmpty || $0.rxRateMBs > 0 }
                if !activeNets.isEmpty {
                    SectionCard(title: "Network", icon: "network") {
                        ForEach(activeNets, id: \.name) { net in
                            NetworkRow(net: net)
                        }
                    }
                }

                // Disk I/O
                if m.diskIO.readRate > 0 || m.diskIO.writeRate > 0 {
                    SectionCard(title: "Disk I/O", icon: "arrow.up.arrow.down") {
                        HStack {
                            Label(String(format: "Read: %.1f MB/s", m.diskIO.readRate), systemImage: "arrow.down")
                                .foregroundColor(.blue)
                            Spacer()
                            Label(String(format: "Write: %.1f MB/s", m.diskIO.writeRate), systemImage: "arrow.up")
                                .foregroundColor(.orange)
                        }
                        .font(.callout)
                        .padding(.vertical, 2)
                    }
                }

                // Thermal
                if m.thermal.cpuTemp > 0 {
                    SectionCard(title: "Thermal", icon: "thermometer.medium") {
                        HStack(spacing: 20) {
                            ThermalCell(label: "CPU", temp: m.thermal.cpuTemp)
                            if m.thermal.gpuTemp > 0 {
                                ThermalCell(label: "GPU", temp: m.thermal.gpuTemp)
                            }
                            if m.thermal.fanCount > 0 {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Fan")
                                        .font(.caption2).foregroundColor(.secondary)
                                    Text("\(m.thermal.fanSpeed) RPM")
                                        .font(.callout.bold())
                                }
                            }
                        }
                    }
                }

                // Battery
                if let bat = m.batteries.first {
                    SectionCard(title: "Battery", icon: "battery.75") {
                        BatteryDetailRow(battery: bat)
                    }
                }

                // Top processes
                if !m.topProcesses.isEmpty {
                    SectionCard(title: "Top Processes", icon: "list.bullet") {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Process")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("CPU")
                                    .frame(width: 68, alignment: .trailing)
                                Text("Memory")
                                    .frame(width: 68, alignment: .trailing)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)

                            ForEach(m.topProcesses.prefix(12), id: \.name) { proc in
                                HStack {
                                    Text(proc.name)
                                        .font(.system(.caption, design: .monospaced))
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    cpuBadge(proc.cpu)
                                    Text(String(format: "%.1f%%", proc.memory))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 68, alignment: .trailing)
                                }
                                .padding(.vertical, 3)
                                Divider()
                            }
                        }
                    }
                }

                Spacer(minLength: 16)
            }
            .padding(16)
        }
    }

    func cpuBadge(_ pct: Double) -> some View {
        Text(String(format: "%.1f%%", pct))
            .font(.caption)
            .foregroundColor(pct > 50 ? .orange : .secondary)
            .frame(width: 68, alignment: .trailing)
    }

    var installPrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundColor(.orange)
            Text("Mole is not installed")
                .font(.title2.bold())
            Button("Visit GitHub") {
                NSWorkspace.shared.open(URL(string: "https://github.com/tw93/Mole")!)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Fetch

    private func fetch() {
        isLoading = true
        MoleRunner.fetchJSON(args: ["status", "--json"]) { data in
            isLoading = false
            guard let data else { notInstalled = true; return }
            if let m = MoleRunner.decodeMetrics(from: data) {
                metrics = m
                notInstalled = false
            }
        }
    }
}

// MARK: - Sub-components

struct GaugeCard: View {
    let title: String
    let value: Double
    let valueLabel: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack(alignment: .bottom, spacing: 6) {
                Text(valueLabel)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Spacer()
                Gauge(value: value) { EmptyView() }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(color)
                    .frame(width: 44, height: 44)
            }
            ProgressView(value: value)
                .tint(value > 0.9 ? .red : value > 0.75 ? .orange : color)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .background(.background.secondary)
        .cornerRadius(12)
        .frame(maxWidth: .infinity)
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
            content()
        }
        .padding(14)
        .background(.background.secondary)
        .cornerRadius(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DiskRow: View {
    let disk: DiskStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: disk.external ? "externaldrive" : "internaldrive")
                    .foregroundColor(disk.external ? .orange : .blue)
                    .font(.caption)
                Text(disk.mount)
                    .font(.callout.bold())
                Spacer()
                Text(String(format: "%.0f / %.0f GB", disk.usedGB, disk.totalGB))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.0f%%", disk.usedPercent))
                    .font(.caption.bold())
                    .foregroundColor(disk.usedPercent > 90 ? .red : .primary)
            }
            ProgressView(value: disk.usedPercent / 100)
                .tint(disk.usedPercent > 90 ? .red : disk.usedPercent > 75 ? .orange : .blue)
        }
        .padding(.vertical, 3)
    }
}

struct NetworkRow: View {
    let net: NetworkStatus

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(net.name)
                    .font(.callout.bold())
                if !net.ip.isEmpty {
                    Text(net.ip)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Label(String(format: "↓ %.1f MB/s", net.rxRateMBs), systemImage: "arrow.down")
                    .font(.caption)
                    .foregroundColor(.blue)
                Label(String(format: "↑ %.1f MB/s", net.txRateMBs), systemImage: "arrow.up")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 3)
    }
}

struct ThermalCell: View {
    let label: String
    let temp: Double

    var color: Color {
        temp > 85 ? .red : temp > 70 ? .orange : .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(String(format: "%.0f°C", temp))
                .font(.callout.bold())
                .foregroundColor(color)
        }
    }
}

struct BatteryDetailRow: View {
    let battery: BatteryStatus

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Charge")
                    .font(.caption2).foregroundColor(.secondary)
                Text(String(format: "%.0f%%", battery.percent))
                    .font(.callout.bold())
            }
            if !battery.status.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Status")
                        .font(.caption2).foregroundColor(.secondary)
                    Text(battery.status)
                        .font(.callout.bold())
                }
            }
            if !battery.timeLeft.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time Left")
                        .font(.caption2).foregroundColor(.secondary)
                    Text(battery.timeLeft)
                        .font(.callout.bold())
                }
            }
            if battery.cycleCount > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cycles")
                        .font(.caption2).foregroundColor(.secondary)
                    Text("\(battery.cycleCount)")
                        .font(.callout.bold())
                }
            }
            if battery.capacity > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Capacity")
                        .font(.caption2).foregroundColor(.secondary)
                    Text("\(battery.capacity)%")
                        .font(.callout.bold())
                }
            }
        }
    }
}

#Preview {
    StatusView()
        .frame(width: 700, height: 600)
}
