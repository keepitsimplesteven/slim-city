import SwiftUI

/// Root content for the iOS app. Hosts the city screen; app-level wiring
/// (persistence, claim loop, connectivity) is assembled in `AppContainer`.
struct ContentView: View {
    @State private var container = AppContainer()

    var body: some View {
        CityScreen(viewModel: container.cityViewModel)
            .task { await container.onForeground() }
    }
}

#Preview {
    ContentView()
}
