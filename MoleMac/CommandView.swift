import SwiftUI

// MARK: - Output line model

struct OutputLine: Identifiable {
    let id = UUID()
    let text: String
    let kind: Kind

    enum Kind { case success, failure, action, info, plain }

    init(_ raw: String) {
        text = raw
        let l = raw.lowercased()
        if raw.hasPrefix("✓") || l.contains("successfully") || l.contains("completed") || l.hasSuffix("done.") {
            kind = .success
        } else if raw.hasPrefix("✗") || raw.hasPrefix("×") || l.contains("error") || l.contains("failed") || l.contains("warning:") {
            kind = .failure
        } else if l.contains("remov") || l.contains("delet") || l.contains("clean") || l.contains("freed") || l.contains("total:") || l.contains("purged") {
            kind = .action
        } else if l.contains("found") || l.contains("scanning") || l.contains("checking") || l.contains("→") || l.contains("->") {
            kind = .info
        } else {
            kind = .plain
        }
    }

    var icon: String? {
        switch kind {
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        case .action:  return "sparkles"
        case .info:    return "arrow.right.circle"
        case .plain:   return nil
        }
    }

    var color: Color {
        switch kind {
        case .success: return .green
        case .failure: return .red
        case .action:  return .orange
        case .info:    return .blue
        case .plain:   return .secondary
        }
    }
}

struct OutputLineRow: View {
    let line: OutputLine

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let icon = line.icon {
                Image(systemName: icon)
                    .foregroundColor(line.color)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 16)
            } else {
                Spacer().frame(width: 24)
            }
            Text(line.text)
                .font(.system(size: 13))
                .foregroundColor(line.kind == .plain ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            line.kind == .success ? Color.green.opacity(0.06) :
            line.kind == .failure ? Color.red.opacity(0.06) :
            line.kind == .action  ? Color.orange.opacity(0.04) : Color.clear
        )
        .cornerRadius(5)
    }
}

// MARK: - Main view

struct CommandView: View {
    let feature: Feature

    @StateObject private var runner = MoleRunner()
    @State private var dryRun = true
    @State private var parsedLines: [OutputLine] = []

    var args: [String] {
        var a = [feature.subcommand]
        if feature.supportsDryRun && dryRun { a.append("--dry-run") }
        return a
    }

    var commandLabel: String { "mo " + args.joined(separator: " ") }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            outputArea
            Divider()
            statusBar
        }
        .navigationTitle(feature.rawValue)
    }

    // MARK: - Toolbar

    var toolbar: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(feature.color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: feature.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(feature.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.helpText)
                    .font(.callout)
                    .lineLimit(1)
                Text(commandLabel)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if feature.supportsDryRun {
                Toggle(isOn: $dryRun) {
                    Label("Dry Run", systemImage: "eye").font(.callout)
                }
                .toggleStyle(.checkbox)
                .help("Preview changes without modifying anything")
            }

            if runner.isRunning {
                Button(role: .destructive, action: { runner.stop() }) {
                    Label("Stop", systemImage: "stop.circle.fill")
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: {
                    parsedLines = []
                    runner.run(args: args)
                }) {
                    Label("Run", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(feature.color)
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Output area

    var outputArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Group {
                    if parsedLines.isEmpty && !runner.isRunning {
                        emptyState
                    } else {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(parsedLines) { line in
                                OutputLineRow(line: line)
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(12)
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onChange(of: runner.output) { newOutput in
                parsedLines = newOutput
                    .components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .map { OutputLine($0) }
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: feature.icon)
                .font(.system(size: 52))
                .foregroundColor(feature.color.opacity(0.35))
            Text("Ready to run")
                .font(.title3)
                .foregroundColor(.secondary)
            if feature.supportsDryRun && dryRun {
                Label("Dry Run mode — no changes will be made", systemImage: "info.circle")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.orange.opacity(0.1))
                    .cornerRadius(8)
            }
            Text("Press ⌘R or click Run to start")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Status bar

    var statusBar: some View {
        HStack(spacing: 8) {
            if runner.isRunning {
                ProgressView().controlSize(.small)
                Text("Running \(commandLabel)…")
                    .font(.caption).foregroundColor(.secondary)
            } else if !parsedLines.isEmpty {
                Image(systemName: runner.exitCode == 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(runner.exitCode == 0 ? .green : .red)
                    .font(.caption)
                Text(runner.exitCode == 0 ? "Completed successfully" : "Exited with code \(runner.exitCode)")
                    .font(.caption).foregroundColor(.secondary)
            } else {
                Text("Ready").font(.caption).foregroundColor(.secondary.opacity(0.6))
            }
            Spacer()
            if !parsedLines.isEmpty && !runner.isRunning {
                Button("Clear") {
                    runner.output = ""
                    parsedLines = []
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 26)
        .background(.bar)
    }
}

#Preview {
    CommandView(feature: .clean)
        .frame(width: 700, height: 500)
}
