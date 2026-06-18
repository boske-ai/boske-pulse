import SwiftUI

private enum DashboardLaunchGate {
    static var didOpen = false
}

struct MenuBarRootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ProductionDashboardView(model: model, style: .menuBar)
            .onAppear {
                guard !DashboardLaunchGate.didOpen else { return }
                DashboardLaunchGate.didOpen = true
                ProductionWindowPresenter.show(model: model)
            }
    }
}
