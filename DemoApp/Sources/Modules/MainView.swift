import SwiftUI

struct MainView: View {
    @ObservedObject private var appViewModel: AppViewModel

    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
    }

    var body: some View {
        TabView {
            BalanceView(appViewModel: appViewModel)
                .tabItem {
                    Label("Balance", systemImage: "creditcard.circle")
                }

            OperationView(appViewModel: appViewModel)
                .tabItem {
                    Label("Operations", systemImage: "list.bullet.circle")
                }

            if Singleton.keyPair != nil {
                SendView()
                    .tabItem {
                        Label("Send", systemImage: "paperplane.circle")
                    }

                ReceiveView()
                    .tabItem {
                        Label("Receive", systemImage: "tray.circle")
                    }
            }
        }
    }
}
