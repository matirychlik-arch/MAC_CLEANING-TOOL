import Foundation

struct MetricsSnapshot: Codable {
    let collectedAt: Date
    let host: String
    let platform: String
    let uptime: String
    let procs: UInt64
    let hardware: HardwareInfo
    let healthScore: Int
    let healthScoreMsg: String
    let cpu: CPUStatus
    let gpu: [GPUStatus]
    let memory: MemoryStatus
    let disks: [DiskStatus]
    let diskIO: DiskIOStatus
    let network: [NetworkStatus]
    let batteries: [BatteryStatus]
    let thermal: ThermalStatus
    let topProcesses: [ProcessEntry]

    enum CodingKeys: String, CodingKey {
        case collectedAt = "collected_at"
        case host, platform, uptime, procs, hardware
        case healthScore = "health_score"
        case healthScoreMsg = "health_score_msg"
        case cpu, gpu, memory, disks
        case diskIO = "disk_io"
        case network, batteries, thermal
        case topProcesses = "top_processes"
    }
}

struct HardwareInfo: Codable {
    let model: String
    let cpuModel: String
    let totalRAM: String
    let diskSize: String
    let osVersion: String

    enum CodingKeys: String, CodingKey {
        case model
        case cpuModel = "cpu_model"
        case totalRAM = "total_ram"
        case diskSize = "disk_size"
        case osVersion = "os_version"
    }
}

struct CPUStatus: Codable {
    let usage: Double
    let perCore: [Double]
    let load1: Double
    let load5: Double
    let load15: Double
    let coreCount: Int
    let logicalCPU: Int

    enum CodingKeys: String, CodingKey {
        case usage
        case perCore = "per_core"
        case load1, load5, load15
        case coreCount = "core_count"
        case logicalCPU = "logical_cpu"
    }
}

struct GPUStatus: Codable {
    let name: String
    let usage: Double
    let memoryUsed: Double
    let memoryTotal: Double
    let coreCount: Int

    enum CodingKeys: String, CodingKey {
        case name, usage
        case memoryUsed = "memory_used"
        case memoryTotal = "memory_total"
        case coreCount = "core_count"
    }
}

struct MemoryStatus: Codable {
    let used: UInt64
    let total: UInt64
    let usedPercent: Double
    let swapUsed: UInt64
    let swapTotal: UInt64
    let pressure: String

    enum CodingKeys: String, CodingKey {
        case used, total
        case usedPercent = "used_percent"
        case swapUsed = "swap_used"
        case swapTotal = "swap_total"
        case pressure
    }

    var usedGB: Double { Double(used) / 1_073_741_824 }
    var totalGB: Double { Double(total) / 1_073_741_824 }
}

struct DiskStatus: Codable {
    let mount: String
    let device: String
    let used: UInt64
    let total: UInt64
    let usedPercent: Double
    let fstype: String
    let external: Bool

    enum CodingKeys: String, CodingKey {
        case mount, device, used, total
        case usedPercent = "used_percent"
        case fstype, external
    }

    var usedGB: Double { Double(used) / 1_073_741_824 }
    var totalGB: Double { Double(total) / 1_073_741_824 }
    var freeGB: Double { max(totalGB - usedGB, 0) }
}

struct DiskIOStatus: Codable {
    let readRate: Double
    let writeRate: Double

    enum CodingKeys: String, CodingKey {
        case readRate = "read_rate"
        case writeRate = "write_rate"
    }
}

struct NetworkStatus: Codable {
    let name: String
    let rxRateMBs: Double
    let txRateMBs: Double
    let ip: String

    enum CodingKeys: String, CodingKey {
        case name
        case rxRateMBs = "rx_rate_mbs"
        case txRateMBs = "tx_rate_mbs"
        case ip
    }
}

struct BatteryStatus: Codable {
    let percent: Double
    let status: String
    let timeLeft: String
    let health: String
    let cycleCount: Int
    let capacity: Int

    enum CodingKeys: String, CodingKey {
        case percent, status
        case timeLeft = "time_left"
        case health
        case cycleCount = "cycle_count"
        case capacity
    }
}

struct ThermalStatus: Codable {
    let cpuTemp: Double
    let gpuTemp: Double
    let fanSpeed: Int
    let fanCount: Int

    enum CodingKeys: String, CodingKey {
        case cpuTemp = "cpu_temp"
        case gpuTemp = "gpu_temp"
        case fanSpeed = "fan_speed"
        case fanCount = "fan_count"
    }
}

struct ProcessEntry: Codable {
    let name: String
    let cpu: Double
    let memory: Double
}
