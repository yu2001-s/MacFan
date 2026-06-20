import Foundation

public enum FanMode: Int, Codable, Equatable {
    case automatic = 0
    case forced = 1
    case auto3 = 3

    public var isAutomatic: Bool {
        self == .automatic || self == .auto3
    }

    public var title: String {
        switch self {
        case .automatic, .auto3:
            return "Auto"
        case .forced:
            return "Manual"
        }
    }
}

public struct FanInfo: Identifiable, Codable, Equatable {
    public let id: Int
    public let name: String
    public let currentRPM: Int
    public let minimumRPM: Int
    public let maximumRPM: Int
    public let targetRPM: Int?
    public let mode: FanMode

    public init(
        id: Int,
        name: String,
        currentRPM: Int,
        minimumRPM: Int,
        maximumRPM: Int,
        targetRPM: Int?,
        mode: FanMode
    ) {
        self.id = id
        self.name = name
        self.currentRPM = currentRPM
        self.minimumRPM = minimumRPM
        self.maximumRPM = maximumRPM
        self.targetRPM = targetRPM
        self.mode = mode
    }

    public var displayName: String {
        name.isEmpty ? "Fan \(id + 1)" : name
    }

    public var safeMinimumRPM: Int {
        max(0, minimumRPM)
    }

    public var safeMaximumRPM: Int {
        max(safeMinimumRPM + 100, maximumRPM)
    }

    public var defaultDraftRPM: Int {
        let base = targetRPM ?? currentRPM
        return base.clamped(to: safeMinimumRPM...safeMaximumRPM)
    }

    public var currentPercentage: Int {
        guard safeMaximumRPM > safeMinimumRPM else { return 0 }
        let fraction = Double(currentRPM - safeMinimumRPM) / Double(safeMaximumRPM - safeMinimumRPM)
        return Int((fraction * 100).rounded()).clamped(to: 0...100)
    }
}

public extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
