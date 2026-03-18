import SwiftUI

enum Feature: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case clean     = "Clean"
    case analyze   = "Analyze"
    case status    = "Status"
    case uninstall = "Uninstall"
    case optimize  = "Optimize"
    case purge     = "Purge"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .clean:     return "trash.fill"
        case .analyze:   return "chart.pie.fill"
        case .status:    return "waveform"
        case .uninstall: return "app.badge.minus"
        case .optimize:  return "bolt.fill"
        case .purge:     return "flame.fill"
        }
    }

    var color: Color {
        switch self {
        case .dashboard: return .blue
        case .clean:     return .orange
        case .analyze:   return .purple
        case .status:    return .green
        case .uninstall: return .red
        case .optimize:  return .yellow
        case .purge:     return .pink
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard: return "System overview"
        case .clean:     return "Caches & logs"
        case .analyze:   return "Disk usage"
        case .status:    return "Live metrics"
        case .uninstall: return "Remove apps"
        case .optimize:  return "Refresh services"
        case .purge:     return "Dev artifacts"
        }
    }

    var subcommand: String {
        switch self {
        case .dashboard: return "status"
        case .clean:     return "clean"
        case .analyze:   return "analyze"
        case .status:    return "status"
        case .uninstall: return "uninstall"
        case .optimize:  return "optimize"
        case .purge:     return "purge"
        }
    }

    var helpText: String {
        switch self {
        case .dashboard: return ""
        case .clean:     return "Removes system caches, user caches, logs, and browser data to free up disk space."
        case .analyze:   return "Scans disk usage and shows a breakdown of what's using the most space."
        case .status:    return "Shows real-time CPU, memory, disk I/O, network, and battery metrics."
        case .uninstall: return "Removes an application along with its preferences, caches, and hidden remnants."
        case .optimize:  return "Rebuilds Spotlight index, clears DNS cache, refreshes launch services, and more."
        case .purge:     return "Finds and removes node_modules, build directories, and other dev artifacts."
        }
    }

    var supportsDryRun: Bool {
        switch self {
        case .clean, .uninstall, .purge: return true
        default: return false
        }
    }
}

struct ContentView: View {
    @State private var selection: Feature = .dashboard

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(Feature.allCases, selection: $selection) { feature in
                SidebarRow(feature: feature)
                    .tag(feature)
            }
            .listStyle(.sidebar)
            .navigationTitle("Mole")
        } detail: {
            switch selection {
            case .dashboard:
                DashboardView()
            case .status:
                StatusView()
            case .analyze:
                AnalyzeView()
            default:
                CommandView(feature: selection)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct SidebarRow: View {
    let feature: Feature

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(feature.color.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: feature.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(feature.color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(feature.rawValue)
                    .fontWeight(.medium)
                    .font(.system(size: 13))
                Text(feature.subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}
