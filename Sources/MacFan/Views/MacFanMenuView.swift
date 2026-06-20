import AppKit
import MacFanCore
import SwiftUI

struct MacFanMenuView: View {
    @EnvironmentObject private var store: FanStore
    let openControlWindow: () -> Void

    var body: some View {
        ControlPanelView(compact: true, openWindow: openControlWindow)
        .environmentObject(store)
    }
}

struct ControlWindowView: View {
    @EnvironmentObject private var store: FanStore

    var body: some View {
        ControlPanelView(compact: false, openWindow: nil)
            .environmentObject(store)
            .frame(minWidth: 420, minHeight: 520)
    }
}

struct ControlPanelView: View {
    @EnvironmentObject private var store: FanStore

    let compact: Bool
    let openWindow: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                if let message = store.errorMessage {
                    errorView(message)
                }

                if store.fans.isEmpty {
                    emptyView
                } else {
                    ForEach(store.fans) { fan in
                        FanControlView(fan: fan)
                    }
                }

                footer
            }
            .padding(14)
        }
        .frame(width: compact ? 380 : nil)
        .onAppear {
            store.refresh()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "fanblades")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 2) {
                Text("MacFan")
                    .font(.headline)
                Text(store.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if store.isBusy {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No controllable fans found")
                .font(.subheadline.weight(.semibold))
            Text("This Mac did not expose the SMC fan keys used by Intel and many Apple Silicon models.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    store.resetAll()
                } label: {
                    Label("All Auto", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .disabled(store.isBusy || store.fans.isEmpty)
                .frame(maxWidth: .infinity)

                Button {
                    store.setAllMaximum()
                } label: {
                    Label("All Max", systemImage: "speedometer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isBusy || store.fans.isEmpty)
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 8) {
                Button {
                    store.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .disabled(store.isBusy)
                .frame(maxWidth: .infinity)

                if let openWindow {
                    Button {
                        openWindow()
                    } label: {
                        Label("Window", systemImage: "macwindow")
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                }

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
            }

            Text(FanFormatters.updated(store.lastUpdated))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !store.fans.isEmpty {
                Label("Privileged helper handles changes", systemImage: "lock")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }
}

struct FanControlView: View {
    @EnvironmentObject private var store: FanStore
    let fan: FanInfo

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fan.displayName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text("\(fan.mode.title) - \(FanFormatters.percentage(fan.currentPercentage))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(FanFormatters.rpm(fan.currentRPM))
                            .font(.subheadline.monospacedDigit())
                        Text("Target \(FanFormatters.rpm(fan.targetRPM))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Slider(
                    value: Binding(
                        get: { Double(store.draftSpeed(for: fan)) },
                        set: { store.setDraftSpeed(Int($0), for: fan, autoApply: true) }
                    ),
                    in: Double(fan.safeMinimumRPM)...Double(fan.safeMaximumRPM)
                )
                .disabled(store.isBusy)

                HStack {
                    Text(FanFormatters.rpm(fan.safeMinimumRPM))
                    Spacer()
                    Text(FanFormatters.rpm(store.draftSpeed(for: fan)))
                        .fontWeight(.semibold)
                    Spacer()
                    Text(FanFormatters.rpm(fan.safeMaximumRPM))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

                HStack {
                    Button {
                        store.setAutomatic(fan)
                    } label: {
                        Label("Auto", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(store.isBusy || fan.mode.isAutomatic)

                    Button {
                        store.setMaximum(fan)
                    } label: {
                        Label("Max", systemImage: "speedometer")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isBusy)
                }
            }
        }
    }
}
