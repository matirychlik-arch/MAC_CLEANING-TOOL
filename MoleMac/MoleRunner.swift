import Foundation

class MoleRunner: ObservableObject {
    @Published var output: String = ""
    @Published var isRunning: Bool = false
    @Published var exitCode: Int32 = 0

    private var process: Process?

    // MARK: - Path resolution

    static var molePath: String? {
        let candidates: [String] = [
            Bundle.main.path(forResource: "mo", ofType: nil),
            "/usr/local/bin/mo",
            "/opt/homebrew/bin/mo",
            "/usr/bin/mo",
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static var isInstalled: Bool { molePath != nil }

    // MARK: - Interactive run (streams output to @Published)

    func run(args: [String]) {
        guard !isRunning else { return }
        guard let path = MoleRunner.molePath else {
            output = """
            ⚠️  mo not found.

            Install Mole first:
              curl -fsSL https://raw.githubusercontent.com/tw93/Mole/main/install.sh | sh

            Then restart this app.
            """
            return
        }

        isRunning = true
        output = ""
        exitCode = 0

        let proc = Process()
        self.process = proc
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-c", ([path] + args).joined(separator: " ")]

        let env = ProcessInfo.processInfo.environment
        proc.environment = env

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            let clean = MoleRunner.stripANSI(str)
            DispatchQueue.main.async { [weak self] in
                self?.output += clean
            }
        }

        proc.terminationHandler = { [weak self] p in
            pipe.fileHandleForReading.readabilityHandler = nil
            // Drain remaining data
            let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
            if !remaining.isEmpty, let str = String(data: remaining, encoding: .utf8) {
                let clean = MoleRunner.stripANSI(str)
                DispatchQueue.main.async { [weak self] in
                    self?.output += clean
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.exitCode = p.terminationStatus
                self?.isRunning = false
            }
        }

        do {
            try proc.run()
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.output += "Error launching mo: \(error.localizedDescription)\n"
                self?.isRunning = false
            }
        }
    }

    func stop() {
        process?.terminate()
    }

    // MARK: - JSON fetch (fire-and-forget, returns Data)

    static func fetchJSON(args: [String], completion: @escaping (Data?) -> Void) {
        guard let path = molePath else {
            completion(nil)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            proc.arguments = ["-c", ([path] + args).joined(separator: " ")]
            proc.environment = ProcessInfo.processInfo.environment

            let outPipe = Pipe()
            proc.standardOutput = outPipe
            proc.standardError = Pipe()

            do {
                try proc.run()
                proc.waitUntilExit()
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                DispatchQueue.main.async { completion(data.isEmpty ? nil : data) }
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    static func decodeMetrics(from data: Data) -> MetricsSnapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MetricsSnapshot.self, from: data)
    }

    // MARK: - ANSI stripping

    static func stripANSI(_ str: String) -> String {
        // Remove ESC[ sequences (colors, cursor movement, etc.)
        let pattern = "\u{1B}\\[[0-9;?]*[A-Za-z]|\u{1B}[()][A-Z0-9]|\u{1B}[^[()]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return str }
        let range = NSRange(str.startIndex..., in: str)
        var result = regex.stringByReplacingMatches(in: str, range: range, withTemplate: "")
        // Remove standalone ESC
        result = result.replacingOccurrences(of: "\u{1B}", with: "")
        // Remove carriage returns (used for line overwrite)
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")
        return result
    }
}
