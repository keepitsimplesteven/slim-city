import SwiftUI
import SlimCityCore

/// The main city screen: the isometric SceneKit view with a resource/score HUD
/// overlaid at the top and a building-select menu along the bottom. All state
/// lives in `CityViewModel`; this view is pure presentation + intent forwarding.
struct CityScreen: View {
    @State private var viewModel: CityViewModel

    init(viewModel: CityViewModel = CityViewModel()) {
        _viewModel = State(initialValue: viewModel)
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
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.lastFeedback)
    }
}

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
