import Foundation

/// A fan curve: how fast the fans run, as a fraction of each fan's minimum-to-maximum range,
/// for a given temperature (the hotter of the CPU and GPU sensor averages).
///
/// Below the first point the fans are handed back to macOS, which keeps them quiet or off.
public enum SmartFanProfile: String, CaseIterable, Codable {
    case quiet
    case balanced
    case cool

    public struct Point: Equatable {
        public let temperature: Double
        public let fraction: Double
    }

    public var title: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    public var points: [Point] {
        switch self {
        case .quiet:
            return [.init(temperature: 65, fraction: 0), .init(temperature: 75, fraction: 0.15),
                    .init(temperature: 83, fraction: 0.4), .init(temperature: 89, fraction: 0.75),
                    .init(temperature: 94, fraction: 1)]
        case .balanced:
            return [.init(temperature: 56, fraction: 0), .init(temperature: 66, fraction: 0.2),
                    .init(temperature: 76, fraction: 0.45), .init(temperature: 84, fraction: 0.75),
                    .init(temperature: 91, fraction: 1)]
        case .cool:
            return [.init(temperature: 48, fraction: 0), .init(temperature: 58, fraction: 0.3),
                    .init(temperature: 68, fraction: 0.6), .init(temperature: 78, fraction: 0.85),
                    .init(temperature: 86, fraction: 1)]
        }
    }

    /// The temperature at which Smart control takes the fans over from macOS.
    public var engageTemperature: Double {
        points[0].temperature
    }

    /// The fan speed this curve asks for at a temperature, or nil below the curve.
    public func fraction(at temperature: Double) -> Double? {
        let points = points
        guard temperature >= points[0].temperature else {
            return nil
        }

        for (lower, upper) in zip(points, points.dropFirst()) where temperature < upper.temperature {
            let position = (temperature - lower.temperature) / (upper.temperature - lower.temperature)
            return lower.fraction + position * (upper.fraction - lower.fraction)
        }

        return points[points.count - 1].fraction
    }
}

/// Turns a stream of temperature readings into fan speeds.
///
/// - Readings are smoothed: rises come through within seconds, falls over half a minute, so a
///   short spike does not rev the fans and a brief dip does not drop them.
/// - Speed rises at once but falls slowly, so the fans do not hunt up and down.
/// - The fans go back to macOS only after the temperature has stayed a few degrees below the
///   curve and the speed has wound down to the minimum.
/// - When any single sensor reaches `emergencyTemperature` the fans go to maximum at once.
public struct SmartFanController {
    public enum Decision: Equatable {
        /// Leave the fans to macOS.
        case system
        /// Run every fan at this fraction of its minimum-to-maximum range.
        case speed(Double)
    }

    public let profile: SmartFanProfile

    public var riseTimeConstant: TimeInterval = 6
    public var fallTimeConstant: TimeInterval = 30
    /// The fastest the speed may fall, as a fraction of the range per second.
    public var fallRate: Double = 0.012
    /// How far below the engage temperature the smoothed reading must go before handing back.
    public var releaseHysteresis: Double = 4
    public var emergencyTemperature: Double = 100

    public private(set) var smoothedTemperature: Double?
    public private(set) var decision: Decision = .system

    public init(profile: SmartFanProfile) {
        self.profile = profile
    }

    @discardableResult
    public mutating func update(temperature: Double, peak: Double? = nil, elapsed: TimeInterval) -> Decision {
        let smoothed = smooth(temperature, elapsed: max(0, elapsed))
        smoothedTemperature = smoothed

        if max(temperature, peak ?? temperature) >= emergencyTemperature {
            decision = .speed(1)
            return decision
        }

        let wanted = profile.fraction(at: smoothed)

        switch decision {
        case .system:
            if let wanted {
                decision = .speed(wanted)
            }

        case .speed(let current):
            let floor = wanted ?? 0
            let next = floor >= current ? floor : max(floor, current - fallRate * elapsed)

            if wanted == nil, next <= 0, smoothed < profile.engageTemperature - releaseHysteresis {
                decision = .system
            } else {
                decision = .speed(next)
            }
        }

        return decision
    }

    private func smooth(_ temperature: Double, elapsed: TimeInterval) -> Double {
        guard let previous = smoothedTemperature else {
            return temperature
        }

        let timeConstant = temperature > previous ? riseTimeConstant : fallTimeConstant
        let weight = 1 - exp(-elapsed / timeConstant)
        return previous + weight * (temperature - previous)
    }
}

public extension FanInfo {
    /// The RPM for a fraction of this fan's minimum-to-maximum range.
    func rpm(atFraction fraction: Double) -> Int {
        let clampedFraction = fraction.clamped(to: 0...1)
        let span = Double(safeMaximumRPM - safeMinimumRPM)
        return safeMinimumRPM + Int((clampedFraction * span).rounded())
    }
}
