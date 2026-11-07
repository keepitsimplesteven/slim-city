#if DEBUG
import SwiftUI
import SlimCityCore

/// Developer-only debug menu for exercising the economy/claim loop without
/// walking around. DEBUG builds only. Pure UI + intent forwarding: every action
/// goes through `CityViewModel`'s debug intents or `AppContainer`'s debug
/// actions, which in turn use the frozen core APIs. No game rules live here.
struct DebugPanel: View {
    let viewModel: CityViewModel
    /// Optional: reset/simulate need the persistence store the container owns.
    /// When nil (e.g. previews or a store-less container), those rows are
    /// disabled and only in-memory crediting is available.
    let container: AppContainer?

    @Environment(\.dismiss) private var dismiss

    // Add X of Y
    @State private var creditType: ResourceType = .material
    @State private var creditAmount = 10

    // Simulate
    @State private var simSource: DebugActions.MetricsSource = .previousDay
    @State private var simDays = 1
    @State private var lastSimResult: String?

    // Reset
    @State private var showResetConfirm = false

    // Resource mode (mirrors the container; the VM is the source of truth)
    private var mode: ResourceMode { viewModel.resourceMode }

    private var storeAvailable: Bool { container?.debugHasStore ?? false }

    var body: some View {
        NavigationStack {
            Form {
                modeSection
                addResourceSection
                simulateSection
                resetSection
            }
            .navigationTitle("Debug Menu")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Resource mode

    private var modeSection: some View {
        Section {
            Picker("Mode", selection: Binding(
                get: { mode },
                set: { newMode in
                    if let container { container.debugSetResourceMode(newMode) }
                    else { viewModel.setResourceMode(newMode) }
                }
            )) {
                Text("HealthKit").tag(ResourceMode.healthKit)
                Text("Manual").tag(ResourceMode.manual)
            }
            .pickerStyle(.segmented)
            if mode == .healthKit, let container {
                Button("Sync HealthKit now") {
                    Task { await container.syncHealthKit() }
                }
                Text(container.healthKitStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Resource mode")
        } footer: {
            Text("HealthKit: Move ring -> up to 100 gold, Exercise -> up to 30 food, Stand -> up to 12 material per day. Each mode keeps its own wallet. Only the HealthKit wallet is saved; Manual resets when the app restarts.")
        }
    }

    // MARK: Add X of Y resource

    private var addResourceSection: some View {
        Section {
            Picker("Type", selection: $creditType) {
                ForEach(ResourceType.allCases, id: \.self) { type in
                    Text(label(for: type)).tag(type)
                }
            }
            Stepper("Amount: \(creditAmount)", value: $creditAmount, in: 1...10_000, step: 10)
            Button("Add \(creditAmount) \(label(for: creditType))") {
                viewModel.debugCredit(creditType, amount: creditAmount)
            }
            .disabled(mode == .healthKit)
        } header: {
            Text("Add resource")
        } footer: {
            if mode == .healthKit {
                Text("Manual mode only. In HealthKit mode, resources come from your activity.")
            }
        }
    }

    // MARK: Simulate X days

    private var simulateSection: some View {
        Section {
            Picker("Source", selection: $simSource) {
                Text("Previous day").tag(DebugActions.MetricsSource.previousDay)
                Text("7-day average").tag(DebugActions.MetricsSource.rollingSevenDayAverage)
            }
            .pickerStyle(.segmented)
            Stepper("Days: \(simDays)", value: $simDays, in: 1...30)
            Button("Simulate \(simDays) day\(simDays == 1 ? "" : "s")") {
                let grant = container?.debugSimulate(days: simDays, source: simSource)
                lastSimResult = describe(grant)
            }
            .disabled(!storeAvailable)
            if let lastSimResult {
                Text(lastSimResult)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Simulate days")
        } footer: {
            Text(storeAvailable
                 ? "Pushes synthetic days through the real claim path (respects the backfill cap). Needs at least one real day of metrics to copy from."
                 : "Unavailable: no persistence store.")
        }
    }

    // MARK: Reset all

    private var resetSection: some View {
        Section {
            Button("Reset all", role: .destructive) {
                showResetConfirm = true
            }
            .disabled(container == nil)
            .confirmationDialog(
                "Reset the city?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset everything", role: .destructive) {
                    container?.debugReset()
                    lastSimResult = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Wipes the city, wallet, and ledger back to a fresh start. This can't be undone.")
            }
        } footer: {
            Text("Starts a fresh game and clears saved state. Ledger rows are zeroed (the persistence API has no row delete).")
        }
    }

    // MARK: Helpers

    private func label(for type: ResourceType) -> String {
        switch type {
        case .material: return "Material"
        case .gold:     return "Gold"
        case .food:     return "Food"
        }
    }

    private func describe(_ grant: ResourceBundle?) -> String {
        guard let grant else { return "Nothing to simulate (no history or no store)." }
        if grant.isEmpty { return "No grant (no claimable source days)." }
        return "Granted ⛏\(grant[.material]) 💰\(grant[.gold]) 🍃\(grant[.food])."
    }
}

#Preview {
    DebugPanel(
        viewModel: CityViewModel(
            state: GameState(wallet: ResourceBundle(material: 100, gold: 100, food: 100)),
            catalog: .default
        ),
        container: nil
    )
}
#endif
