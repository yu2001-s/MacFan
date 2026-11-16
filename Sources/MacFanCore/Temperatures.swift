import Foundation

/// CPU and GPU die temperatures at one moment, in degrees Celsius.
///
/// `cpu` and `gpu` average their sensors, which follows how much heat the chip puts out (and so how
/// hot the case gets) without jumping with every burst on one core. `peak` is the hottest single sensor.
public struct TemperatureReading: Codable, Equatable {
    public let cpu: Double?
    public let gpu: Double?
    public let peak: Double?

    public init(cpu: Double?, gpu: Double?, peak: Double?) {
        self.cpu = cpu
        self.gpu = gpu
        self.peak = peak
    }

    /// The hotter of the CPU and GPU averages, which is what drives Smart fan control.
    public var hotter: Double? {
        [cpu, gpu].compactMap { $0 }.max()
    }
}

/// Reads the CPU and GPU die temperatures from the SMC.
///
/// The sensor keys differ between Mac models, so they are found once by listing every SMC key
/// and keeping the ones that name a CPU or GPU die sensor on this kind of Mac.
public final class TemperatureSensors {
    public let cpuKeys: [String]
    public let gpuKeys: [String]

    private let client: SMCClient

    /// Sensors outside this range are unplugged or report garbage, and are ignored.
    private static let plausibleRange = 1.0...130.0

    public init(client: SMCClient) throws {
        self.client = client

        let keys = try client.allKeys()
        cpuKeys = keys.filter(Self.isCPUKey)
        gpuKeys = keys.filter(Self.isGPUKey)
    }

    public var isEmpty: Bool {
        cpuKeys.isEmpty && gpuKeys.isEmpty
    }

    public func read() -> TemperatureReading {
        let cpu = values(of: cpuKeys)
        let gpu = values(of: gpuKeys)
        return TemperatureReading(cpu: Self.mean(cpu), gpu: Self.mean(gpu), peak: (cpu + gpu).max())
    }

    private func values(of keys: [String]) -> [Double] {
        keys
            .compactMap { client.readTemperature($0) }
            .filter { Self.plausibleRange.contains($0) }
    }

    private static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    #if arch(arm64)
    // Apple silicon: Tp* performance cores, Te* efficiency cores, Tf* cores on M3 and later, Tg* GPU.
    private static func isCPUKey(_ key: String) -> Bool {
        key.hasPrefix("Tp") || key.hasPrefix("Te") || key.hasPrefix("Tf")
    }

    private static func isGPUKey(_ key: String) -> Bool {
        key.hasPrefix("Tg")
    }
    #else
    // Intel: TC0P proximity, TC0D/TC0E/TC0F die, TCXC PECI, TC1C... per-core; TG0P/TG0D GPU.
    private static func isCPUKey(_ key: String) -> Bool {
        let characters = Array(key)
        guard characters.count == 4, characters[0] == "T", characters[1] == "C" else {
            return false
        }
        return key == "TCXC" || (characters[2].isNumber && "CDEFP".contains(characters[3]))
    }

    private static func isGPUKey(_ key: String) -> Bool {
        key == "TG0P" || key == "TG0D"
    }
    #endif
}
