import SwiftUI

@main
struct AppView: App {
    @StateObject var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            if viewModel.stellarKit != nil {
                MainView(appViewModel: viewModel)
            } else {
                LoginView(appViewModel: viewModel)
            }
        }
    }
}
