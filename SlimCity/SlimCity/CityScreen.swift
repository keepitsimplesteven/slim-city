import SwiftUI
import SlimCityCore

/// The main city screen: the isometric SceneKit view with a resource/score HUD
/// overlaid at the top and a building-select menu along the bottom. All state
/// lives in `CityViewModel`; this view is pure presentation + intent forwarding.
struct CityScreen: View {
    @State private var viewModel: CityViewModel

    #if DEBUG
    /// The app container, used only by the debug menu to reach reset/simulate
    /// actions that need the persistence store. Optional so previews (and any
    /// VM-only call site) still work without a full container.
    private let container: AppContainer?
    @State private var showDebugPanel = false

    @MainActor
    init(viewModel: CityViewModel, container: AppContainer? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.container = container
    }
    #else
    @MainActor
    init(viewModel: CityViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    #endif

    /// Convenience initializer that builds a default view model on the main
    /// actor. Kept separate from the designated init because a default argument
    /// value is evaluated in a nonisolated context and therefore cannot call
    /// `CityViewModel`'s @MainActor initializer.
    @MainActor
    init() {
        _viewModel = State(initialValue: CityViewModel())
        #if DEBUG
        self.container = nil
        #endif
    }

    var body: some View {
        ZStack {
            #if canImport(UIKit)
            CitySceneView(viewModel: viewModel)
                .ignoresSafeArea()
            #else
            Color.gray.opacity(0.2).ignoresSafeArea()
            #endif

            VStack {
                WalletHUD(totals: viewModel.walletTotals, score: viewModel.score)
                Spacer()
                if let feedback = viewModel.lastFeedback, !feedback.didPlace {
                    FeedbackBanner(message: feedback.message)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                BuildMenu(
                    buildings: viewModel.menuBuildings,
                    selectedID: viewModel.selectedBuildingID,
                    onSelect: { viewModel.selectBuilding(id: $0) }
                )
            }
            .padding()

            #if DEBUG
            // Developer-only entry point, pinned top-trailing clear of the HUD.
            VStack {
                HStack {
                    Spacer()
                    DebugMenuButton { showDebugPanel = true }
                }
                Spacer()
            }
            .padding(.top, 64)
            .padding(.trailing, 12)
            #endif
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.lastFeedback)
        #if DEBUG
        .sheet(isPresented: $showDebugPanel) {
            DebugPanel(viewModel: viewModel, container: container)
        }
        #endif
    }
}

#if DEBUG
/// The small corner affordance that opens the debug menu. DEBUG builds only.
struct DebugMenuButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "ladybug.fill")
                .font(.title3)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("debug-menu-button")
        .accessibilityLabel("Debug menu")
    }
}
#endif

/// Top HUD: material / gold / food totals and the current city score.
struct WalletHUD: View {
    let totals: [(type: ResourceType, amount: Int)]
    let score: Int

    var body: some View {
        HStack(spacing: 16) {
            ForEach(totals, id: \.type) { entry in
                Label("\(entry.amount)", systemImage: icon(for: entry.type))
                    .labelStyle(.titleAndIcon)
            }
            Spacer()
            Label("\(score)", systemImage: "star.fill")
        }
        .font(.headline.monospacedDigit())
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func icon(for type: ResourceType) -> String {
        switch type {
        case .material: return "cube.fill"
        case .gold:     return "dollarsign.circle.fill"
        case .food:     return "leaf.fill"
        }
    }
}

/// Bottom build menu: one chip per catalog building; tap to select/deselect.
struct BuildMenu: View {
    let buildings: [BuildingDefinition]
    let selectedID: String?
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(buildings) { building in
                    Button {
                        onSelect(building.id)
                    } label: {
                        VStack(spacing: 2) {
                            Text(building.displayName).font(.subheadline.bold())
                            Text(costSummary(building.cost)).font(.caption2.monospacedDigit())
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedID == building.id ? AnyShapeStyle(.tint) : AnyShapeStyle(.ultraThinMaterial),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .foregroundStyle(selectedID == building.id ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func costSummary(_ cost: ResourceBundle) -> String {
        "⛏\(cost[.material]) 💰\(cost[.gold]) 🍃\(cost[.food])"
    }
}

/// A transient banner for placement rejection feedback.
struct FeedbackBanner: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.subheadline.bold())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .foregroundStyle(.primary)
    }
}

#Preview {
    CityScreen(viewModel: CityViewModel(
        state: GameState(wallet: ResourceBundle(material: 100, gold: 100, food: 100)),
        catalog: .default
    ))
}
