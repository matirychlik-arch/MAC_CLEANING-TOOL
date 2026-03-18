import SwiftUI

// MARK: - Model

private struct FolderItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let icon: String
    let color: Color
    var sizeBytes: Int64 = -1
}

private func duBytes(at path: String) -> Int64 {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/du")
    proc.arguments = ["-skx", path]
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = Pipe()
    guard (try? proc.run()) != nil else { return 0 }
    let sem = DispatchSemaphore(value: 0)
    proc.terminationHandler = { _ in sem.signal() }
    if sem.wait(timeout: .now() + 20) == .timedOut { proc.terminate(); return 0 }
    let text = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let kb = Int64(text.components(separatedBy: "\t").first?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0
    return kb * 1024
}

private func fmtSz(_ bytes: Int64) -> String {
    guard bytes >= 0 else { return "…" }
    if bytes >= 1_073_741_824 { return String(format: "%.1f GB", Double(bytes) / 1_073_741_824) }
    if bytes >= 1_048_576    { return String(format: "%.0f MB", Double(bytes) / 1_048_576) }
    return "\(bytes / 1024) KB"
}

private class AnalyzeModel: ObservableObject {
    @Published var folders: [FolderItem] = []
    @Published var rootDisk: DiskStatus?
    @Published var scanning = false

    func startScan() {
        scanning = true
        folders = Self.defaultFolders()

        MoleRunner.fetchJSON(args: ["status", "--json"]) { [weak self] data in
            if let data, let m = MoleRunner.decodeMetrics(from: data) {
                self?.rootDisk = m.disks.first { $0.mount == "/" }
            }
        }

        let snapshot = folders
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for i in snapshot.indices {
                let size = duBytes(at: snapshot[i].path)
                DispatchQueue.main.async { [weak self] in
                    guard let self, i < self.folders.count else { return }
                    self.folders[i].sizeBytes = size
                }
            }
            DispatchQueue.main.async { [weak self] in self?.scanning = false }
        }
    }

    private static func defaultFolders() -> [FolderItem] {
        let h = NSHomeDirectory()
        return [
            FolderItem(name: "User Caches",          path: "\(h)/Library/Caches",              icon: "clock.arrow.circlepath", color: .orange),
            FolderItem(name: "Logs",                  path: "\(h)/Library/Logs",                icon: "doc.text",               color: .yellow),
            FolderItem(name: "Application Support",   path: "\(h)/Library/Application Support", icon: "folder.badge.gearshape", color: .blue),
            FolderItem(name: "Downloads",             path: "\(h)/Downloads",                   icon: "arrow.down.circle",      color: .cyan),
            FolderItem(name: "Trash",                 path: "\(h)/.Trash",                      icon: "trash",                  color: .red),
            FolderItem(name: "Desktop",               path: "\(h)/Desktop",                     icon: "desktopcomputer",        color: .indigo),
            FolderItem(name: "Documents",             path: "\(h)/Documents",                   icon: "doc.richtext",           color: .purple),
            FolderItem(name: "Movies",                path: "\(h)/Movies",                      icon: "film",                   color: .pink),
        ]
    }
}

// MARK: - View

struct AnalyzeView: View {
    @StateObject private var model = AnalyzeModel()

    private var maxBytes: Int64 { model.folders.map { max($0.sizeBytes, 0) }.max() ?? 1 }
    private var totalBytes: Int64 { model.folders.filter { $0.sizeBytes > 0 }.reduce(0) { $0 + $1.sizeBytes } }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                diskCard
                folderCard
            }
            .padding(16)
        }
        .navigationTitle("Analyze")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: model.startScan) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(model.scanning)
            }
        }
        .onAppear(perform: model.startScan)
    }

    // MARK: Disk overview

    @ViewBuilder
    private var diskCard: some View {
        if let disk = model.rootDisk {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 34, height: 34)
                        Image(systemName: "internaldrive")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Macintosh HD").font(.headline)
                        Text(String(format: "%.0f GB total", disk.totalGB))
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f GB", disk.usedGB)).font(.title3.bold())
                        Text("used").font(.caption).foregroundColor(.secondary)
                    }
                }
                ProgressView(value: disk.usedPercent / 100)
                    .tint(disk.usedPercent > 90 ? .red : disk.usedPercent > 75 ? .orange : .blue)
                HStack {
                    Label(
                        String(format: "%.1f GB used  (%.0f%%)", disk.usedGB, disk.usedPercent),
                        systemImage: "square.fill"
                    ).foregroundColor(.blue)
                    Spacer()
                    Label(
                        String(format: "%.1f GB free", disk.freeGB),
                        systemImage: "square"
                    ).foregroundColor(.secondary)
                }.font(.caption)
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        } else {
            Color(nsColor: .controlBackgroundColor)
                .frame(height: 100).cornerRadius(12)
                .overlay(ProgressView())
        }
    }

    // MARK: Folder table

    private var folderCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Folder Analysis").font(.headline)
                Spacer()
                if model.scanning {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Scanning…").font(.caption).foregroundColor(.secondary)
                    }
                } else {
                    Text("Total: \(fmtSz(totalBytes))")
                        .font(.caption.bold()).foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 10)

            ForEach(model.folders.indices, id: \.self) { i in
                folderRow(model.folders[i])
                if i < model.folders.count - 1 {
                    Divider().padding(.leading, 32)
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    private func folderRow(_ entry: FolderItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.icon)
                .foregroundColor(entry.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.name).font(.callout)
                    Spacer()
                    if entry.sizeBytes < 0 {
                        ProgressView().controlSize(.mini)
                    } else {
                        Text(fmtSz(entry.sizeBytes))
                            .font(.caption.bold())
                            .foregroundColor(entry.sizeBytes > 500_000_000 ? .orange : .secondary)
                    }
                }
                if entry.sizeBytes >= 0 {
                    ProgressView(value: Double(max(entry.sizeBytes, 0)) / Double(maxBytes))
                        .tint(entry.color.opacity(0.7))
                }
            }

            Button {
                NSWorkspace.shared.open(URL(fileURLWithPath: entry.path))
            } label: {
                Image(systemName: "folder.badge.magnifyingglass").foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open in Finder")
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    AnalyzeView().frame(width: 700, height: 600)
}
