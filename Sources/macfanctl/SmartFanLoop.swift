import Darwin
import Foundation
import MacFanCore

/// Runs Smart fan control until it is stopped: reads the temperatures every `interval` seconds,
/// sets the fans from the profile's curve, and hands the fans back to macOS when it stops.
///
/// It is meant to run under launchd (see the Toolbox Raycast extension's Smart Fan command), which
/// stops it with SIGTERM and restarts it if it crashes.
final class SmartFanLoop {
    private let client: SMCClient
    private let sensors: TemperatureSensors
    private let interval: TimeInterval
    private let dryRun: Bool
    private var controller: SmartFanController

    private var signalSources: [DispatchSourceSignal] = []
    private var timer: DispatchSourceTimer?
    private var lastTick: TimeInterval?
    private var consecutiveFailures = 0
    /// nil until the first decision is applied, so the first tick always takes or releases control.
    private var handedToSystem: Bool?
    private var lastLoggedFraction: Double?

    private static let maximumConsecutiveFailures = 5
    /// Rewrite a fan's target only when it is off by at least this much.
    private static let rpmTolerance = 50

    init(client: SMCClient, profile: SmartFanProfile, interval: TimeInterval, dryRun: Bool) throws {
        self.client = client
        self.interval = interval
        self.dryRun = dryRun
        controller = SmartFanController(profile: profile)
        sensors = try TemperatureSensors(client: client)

        guard !sensors.isEmpty else {
            throw SmartFanError.noSensors
        }
    }

    func run() -> Never {
        setvbuf(stdout, nil, _IOLBF, 0)

        for signalNumber in [SIGTERM, SIGINT, SIGHUP] {
            signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler { [unowned self] in
                stop(reason: "signal \(signalNumber)", status: EXIT_SUCCESS)
            }
            source.resume()
            signalSources.append(source)
        }

        log("Smart fan started: \(controller.profile.title) profile, \(sensors.cpuKeys.count) CPU and \(sensors.gpuKeys.count) GPU sensors, every \(interval)s\(dryRun ? ", dry run" : "")")

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(250))
        timer.setEventHandler { [unowned self] in
            tick()
        }
        timer.resume()
        self.timer = timer

        dispatchMain()
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        // After sleep or a stall, treat the gap as one normal step rather than a long one.
        let elapsed = lastTick.map { min(now - $0, interval * 3) } ?? interval
        lastTick = now

        let reading = sensors.read()
        guard let temperature = reading.hotter else {
            fail("No temperature reading")
            return
        }

        let decision = controller.update(temperature: temperature, peak: reading.peak, elapsed: elapsed)

        do {
            try apply(decision, temperature: temperature)
            consecutiveFailures = 0
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func apply(_ decision: SmartFanController.Decision, temperature: Double) throws {
        let smoothed = controller.smoothedTemperature ?? temperature

        switch decision {
        case .system:
            if dryRun {
                log("\(Self.format(temperature)) (smoothed \(Self.format(smoothed))): macOS controls the fans")
            }

            guard handedToSystem != true else {
                return
            }

            if !dryRun {
                try client.resetFanControl()
            }
            handedToSystem = true
            lastLoggedFraction = nil
            log("\(Self.format(smoothed)): fans handed back to macOS")

        case .speed(let fraction):
            let fans = try client.readFans()
            let targets = fans.map { ($0, $0.rpm(atFraction: fraction)) }

            if !dryRun {
                for (fan, rpm) in targets where fan.mode != .forced || abs((fan.targetRPM ?? 0) - rpm) >= Self.rpmTolerance {
                    try client.setFanSpeed(fan.id, rpm: rpm)
                }
            }

            let engaging = handedToSystem != false
            handedToSystem = false

            if dryRun || engaging || abs(fraction - (lastLoggedFraction ?? -1)) >= 0.1 {
                lastLoggedFraction = fraction
                let rpms = targets.map { String($0.1) }.joined(separator: "/")
                log("\(Self.format(temperature)) (smoothed \(Self.format(smoothed))): \(Int((fraction * 100).rounded()))%, \(rpms) RPM")
            }
        }
    }

    private func fail(_ message: String) {
        consecutiveFailures += 1
        log("\(message) (\(consecutiveFailures)/\(Self.maximumConsecutiveFailures))")

        if consecutiveFailures >= Self.maximumConsecutiveFailures {
            stop(reason: "too many failures", status: EXIT_FAILURE)
        }
    }

    private func stop(reason: String, status: Int32) -> Never {
        timer?.cancel()

        if !dryRun {
            do {
                try client.resetFanControl()
                log("Stopped (\(reason)); fans handed back to macOS")
            } catch {
                log("Stopped (\(reason)); could not hand fans back to macOS: \(error.localizedDescription)")
            }
        } else {
            log("Stopped (\(reason))")
        }

        exit(status)
    }

    private func log(_ message: String) {
        print("\(Self.timestamp.string(from: Date())) \(message)")
    }

    private static func format(_ temperature: Double) -> String {
        String(format: "%.1f°C", temperature)
    }

    private static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

enum SmartFanError: LocalizedError {
    case noSensors

    var errorDescription: String? {
        switch self {
        case .noSensors:
            return "No CPU or GPU temperature sensors were found on this Mac."
        }
    }
}
