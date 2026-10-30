import SwiftUI
import SlimCityCore

/// Minimal watch UI: today's activity metrics and the current resource totals,
/// plus a manual "sync" action that collects and relays to the phone. HealthKit
/// authorization is requested on appear; passive collection happens in the
/// collector/connectivity managers.
struct ContentView: View {
    @State private var model = WatchViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Today").font(.headline)
                metricRow("Steps", value: "\(model.steps)", systemImage: "figure.walk")
                metricRow("Energy", value: "\(Int(model.energy)) kcal", systemImage: "flame.fill")
                metricRow("Exercise", value: "\(Int(model.exercise)) min", systemImage: "timer")

                Divider()

                Text("City").font(.headline)
                metricRow("Material", value: "\(model.wallet[.material])", systemImage: "cube.fill")
                metricRow("Gold", value: "\(model.wallet[.gold])", systemImage: "dollarsign.circle.fill")
                metricRow("Food", value: "\(model.wallet[.food])", systemImage: "leaf.fill")

                Button("Sync to Phone") { Task { await model.syncNow() } }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)

                if let status = model.statusLine {
                    Text(status).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .task { await model.start() }
    }

    private func metricRow(_ title: String, value: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage).font(.caption)
            Spacer()
            Text(value).font(.caption.monospacedDigit().bold())
        }
    }
}

/// Owns watch-side state and bridges the collector + connectivity managers.
@MainActor
@Observable
final class WatchViewModel {
    var steps: Int = 0
    var energy: Double = 0
    var exercise: Double = 0
    var wallet: ResourceBundle = .zero
    var statusLine: String?

    #if canImport(HealthKit)
    private let collector = WatchHealthCollector()
    #endif
    #if canImport(WatchConnectivity)
    private let connectivity = WatchConnectivityManager()
    #endif

    func start() async {
        #if canImport(HealthKit)
        _ = try? await collector.requestAuthorization()
        await refresh()
        #else
        statusLine = "HealthKit unavailable"
        #endif
    }

    func refresh() async {
        #if canImport(HealthKit)
        if let sample = try? await collector.today() {
            steps = sample.stepCount
            energy = sample.activeEnergyKilocalories
            exercise = sample.exerciseMinutes
        }
        #endif
    }

    func syncNow() async {
        #if canImport(HealthKit) && canImport(WatchConnectivity)
        await refresh()
        guard let sample = try? await collector.today() else {
            statusLine = "No data"
            return
        }
        let payload = WatchHealthPayload(days: [sample], wallet: wallet)
        let via = connectivity.relay(payload)
        statusLine = "Sent via \(via)"
        #else
        statusLine = "Sync unavailable"
        #endif
    }
}

#Preview {
    ContentView()
}
