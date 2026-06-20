import Darwin
import Foundation
import MacFanCore

@main
struct MacFanControlTool {
    static func main() {
        do {
            try run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.writeLine(error.localizedDescription)
            exit(EXIT_FAILURE)
        }
    }

    private static func run(arguments: [String]) throws {
        guard let command = arguments.first else {
            printUsage()
            throw ToolError.invalidArguments("Missing command.")
        }

        let options = try Options(arguments: Array(arguments.dropFirst()))
        let client = try SMCClient()

        switch command {
        case "version":
            print(ToolVersion.current)

        case "fans", "list":
            let fans = try client.readFans()
            if options.flag("json") {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                FileHandle.standardOutput.write(try encoder.encode(fans))
                FileHandle.standardOutput.writeLine("")
            } else {
                printFans(fans)
            }

        case "set-speed":
            let id = try options.requiredInt("id")
            let rpm = try options.requiredInt("rpm")
            try client.setFanSpeed(id, rpm: rpm)
            print("Set fan \(id) target to \(rpm) RPM")

        case "set-mode":
            let id = try options.requiredInt("id")
            let mode = try options.requiredFanMode("mode")
            try client.setFanMode(id, mode: mode)
            print("Set fan \(id) mode to \(mode.title)")

        case "reset":
            try client.resetFanControl()
            print("Reset all fans to automatic control")

        case "doctor":
            print("uid: \(getuid())")
            print("euid: \(geteuid())")

        default:
            printUsage()
            throw ToolError.invalidArguments("Unknown command: \(command)")
        }
    }

    private static func printFans(_ fans: [FanInfo]) {
        guard !fans.isEmpty else {
            print("No fans found")
            return
        }

        for fan in fans {
            print("\(fan.id): \(fan.displayName)")
            print("  Current: \(fan.currentRPM) RPM")
            print("  Minimum: \(fan.minimumRPM) RPM")
            print("  Maximum: \(fan.maximumRPM) RPM")
            print("  Target: \(fan.targetRPM.map(String.init) ?? "--") RPM")
            print("  Mode: \(fan.mode.title)")
        }
    }

    private static func printUsage() {
        FileHandle.standardError.writeLine("""
        usage:
          macfanctl fans [--json]
          macfanctl set-speed --id <fan-id> --rpm <rpm>
          macfanctl set-mode --id <fan-id> --mode <auto|manual|0|1>
          macfanctl reset
          macfanctl doctor
          macfanctl version
        """)
    }
}

private enum ToolVersion {
    static let current = "0.2.0"
}

private enum ToolError: LocalizedError {
    case invalidArguments(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let message):
            return message
        }
    }
}

private struct Options {
    private var values: [String: String] = [:]
    private var flags: Set<String> = []

    init(arguments: [String]) throws {
        var index = 0

        while index < arguments.count {
            let rawKey = arguments[index]
            guard rawKey.hasPrefix("--") else {
                throw ToolError.invalidArguments("Unexpected argument: \(rawKey)")
            }

            let key = String(rawKey.dropFirst(2))
            let nextIndex = index + 1

            if nextIndex >= arguments.count || arguments[nextIndex].hasPrefix("--") {
                flags.insert(key)
                index += 1
            } else {
                values[key] = arguments[nextIndex]
                index += 2
            }
        }
    }

    func flag(_ key: String) -> Bool {
        flags.contains(key)
    }

    func requiredInt(_ key: String) throws -> Int {
        guard let value = values[key], let intValue = Int(value) else {
            throw ToolError.invalidArguments("Missing or invalid --\(key).")
        }
        return intValue
    }

    func requiredFanMode(_ key: String) throws -> FanMode {
        guard let value = values[key]?.lowercased() else {
            throw ToolError.invalidArguments("Missing --\(key).")
        }

        switch value {
        case "auto", "automatic", "0":
            return .automatic
        case "manual", "forced", "1":
            return .forced
        default:
            throw ToolError.invalidArguments("Invalid --\(key): \(value).")
        }
    }
}

private extension FileHandle {
    func writeLine(_ text: String) {
        write((text + "\n").data(using: .utf8) ?? Data())
    }
}
