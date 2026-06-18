import SwiftUI

struct MenuBarRootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ProductionDashboardView(model: model, style: .menuBar, surface: .menuBarPopover)
            .onAppear {
                DashboardPresentation.menuBarPopoverDidOpen()
            }
    }
}
