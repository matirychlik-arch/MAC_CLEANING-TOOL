import SwiftUI

struct CommandView: View {
    let feature: Feature

    @StateObject private var runner = MoleRunner()
    @State private var dryRun = true
    @State private var scrollToBottom = false

    var args: [String] {
        var a = [feature.subcommand]
        if feature.supportsDryRun && dryRun { a.append("--dry-run") }
        if feature == .analyze { a.append("--json") }
        return a
    }

    var commandLabel: String {
        "mo " + args.joined(separator: " ")
    }

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
            // Feature icon
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
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(commandLabel)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if feature.supportsDryRun {
                Toggle(isOn: $dryRun) {
                    Label("Dry Run", systemImage: "eye")
                        .font(.callout)
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
                Button(action: { runner.run(args: args) }) {
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
                    if runner.output.isEmpty && !runner.isRunning {
                        emptyState
                    } else {
                        Text(runner.output)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                }
                Color.clear
                    .frame(height: 1)
                    .id("bottom")
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onChange(of: runner.output) { _ in
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
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if !runner.output.isEmpty {
                Image(systemName: runner.exitCode == 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(runner.exitCode == 0 ? .green : .red)
                    .font(.caption)
                Text(runner.exitCode == 0 ? "Completed successfully" : "Exited with code \(runner.exitCode)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Ready")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.6))
            }
            Spacer()
            if !runner.output.isEmpty && !runner.isRunning {
                Button("Clear") {
                    runner.output = ""
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
