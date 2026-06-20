import Foundation
import MacFanCore

final class FanStore: ObservableObject {
    @Published private(set) var fans: [FanInfo] = []
    @Published private(set) var isBusy = false
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?
    @Published var draftSpeeds: [Int: Int] = [:]

    private let service: FanManaging
    private let workQueue = DispatchQueue(label: "com.shaoyuhuang.MacFan.smc", qos: .userInitiated)
    private var refreshTimer: Timer?
    private var pendingApplyWorkItems: [Int: DispatchWorkItem] = [:]

    init(service: FanManaging) {
        self.service = service
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.refresh(silent: true)
        }
    }

    deinit {
        refreshTimer?.invalidate()
        pendingApplyWorkItems.values.forEach { $0.cancel() }
    }

    var menuBarTitle: String {
        guard !fans.isEmpty else { return "MacFan" }

        if fans.count == 1 {
            return FanFormatters.rpm(fans[0].currentRPM)
        }

        let average = fans.map(\.currentRPM).reduce(0, +) / fans.count
        return FanFormatters.rpm(average)
    }

    var statusText: String {
        guard !fans.isEmpty else { return "No fans" }
        return fans.contains(where: { !$0.mode.isAutomatic }) ? "Manual active" : "Automatic"
    }

    func refresh(silent: Bool = false) {
        run(silent: silent, replaceDrafts: false) { [service] in
            try service.readFans()
        }
    }

    func setDraftSpeed(_ rpm: Int, for fan: FanInfo, autoApply: Bool = false) {
        let sanitizedRPM = snappedRPM(rpm, for: fan)
        draftSpeeds[fan.id] = sanitizedRPM

        if autoApply {
            scheduleApplySpeed(sanitizedRPM, for: fan)
        }
    }

    func draftSpeed(for fan: FanInfo) -> Int {
        (draftSpeeds[fan.id] ?? fan.defaultDraftRPM).clamped(to: fan.safeMinimumRPM...fan.safeMaximumRPM)
    }

    func setMaximum(_ fan: FanInfo) {
        let rpm = fan.safeMaximumRPM
        draftSpeeds[fan.id] = rpm
        cancelPendingApply(for: fan.id)

        run(replaceDrafts: false) { [service] in
            try service.setFanSpeed(id: fan.id, rpm: rpm)
            return try service.readFans()
        }
    }

    func setAllMaximum() {
        let fans = self.fans
        guard !fans.isEmpty else { return }

        pendingApplyWorkItems.values.forEach { $0.cancel() }
        pendingApplyWorkItems.removeAll()

        for fan in fans {
            draftSpeeds[fan.id] = fan.safeMaximumRPM
        }

        run(replaceDrafts: false) { [service] in
            for fan in fans {
                try service.setFanSpeed(id: fan.id, rpm: fan.safeMaximumRPM)
            }
            return try service.readFans()
        }
    }

    func setManual(_ fan: FanInfo) {
        run(replaceDrafts: true) { [service] in
            try service.setFanMode(id: fan.id, mode: .forced)
            return try service.readFans()
        }
    }

    func setAutomatic(_ fan: FanInfo) {
        cancelPendingApply(for: fan.id)

        run(replaceDrafts: false) { [service] in
            try service.setFanMode(id: fan.id, mode: .automatic)
            return try service.readFans()
        }
    }

    func resetAll() {
        pendingApplyWorkItems.values.forEach { $0.cancel() }
        pendingApplyWorkItems.removeAll()

        run(replaceDrafts: true) { [service] in
            try service.resetFanControl()
            return try service.readFans()
        }
    }

    private func run(
        silent: Bool = false,
        replaceDrafts: Bool,
        operation: @escaping () throws -> [FanInfo]
    ) {
        if !silent {
            isBusy = true
        }

        workQueue.async { [weak self] in
            do {
                let fans = try operation()

                DispatchQueue.main.async {
                    guard let self else { return }
                    self.fans = fans
                    self.syncDrafts(with: fans, replaceExisting: replaceDrafts)
                    self.errorMessage = nil
                    self.lastUpdated = Date()
                    self.isBusy = false
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.errorMessage = error.localizedDescription
                    self.isBusy = false
                }
            }
        }
    }

    private func scheduleApplySpeed(_ rpm: Int, for fan: FanInfo) {
        cancelPendingApply(for: fan.id)

        let fanID = fan.id
        let workItem = DispatchWorkItem { [weak self] in
            self?.run(silent: true, replaceDrafts: false) { [service = self?.service] in
                guard let service else { return [] }
                try service.setFanSpeed(id: fanID, rpm: rpm)
                return try service.readFans()
            }
        }

        pendingApplyWorkItems[fanID] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private func cancelPendingApply(for fanID: Int) {
        pendingApplyWorkItems[fanID]?.cancel()
        pendingApplyWorkItems[fanID] = nil
    }

    private func snappedRPM(_ rpm: Int, for fan: FanInfo) -> Int {
        let clampedRPM = rpm.clamped(to: fan.safeMinimumRPM...fan.safeMaximumRPM)
        return (Int((Double(clampedRPM) / 50.0).rounded()) * 50)
            .clamped(to: fan.safeMinimumRPM...fan.safeMaximumRPM)
    }

    private func syncDrafts(with fans: [FanInfo], replaceExisting: Bool) {
        let fanIDs = Set(fans.map(\.id))
        draftSpeeds = draftSpeeds.filter { fanIDs.contains($0.key) }

        for fan in fans {
            if replaceExisting || draftSpeeds[fan.id] == nil {
                draftSpeeds[fan.id] = fan.defaultDraftRPM
            }
        }
    }
}
