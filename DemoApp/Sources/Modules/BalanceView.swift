import SwiftUI

struct BalanceView: View {
    @StateObject private var viewModel = BalanceViewModel()
    @ObservedObject private var appViewModel: AppViewModel

    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                info(title: "Address", value: viewModel.address)
                info(title: "Account Sync State", value: viewModel.syncState.description)
                info(
                    title: "Transaction Sync State",
                    value: viewModel.transactionSyncState.description
                )

                Divider()

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(
                            viewModel.assetBalances.sorted {
                                $0.asset.code < $1.asset.code
                            }, id: \.asset.id
                        ) { assetBalance in
                            info(
                                title: assetBalance.asset.id,
                                value: "\(assetBalance.balance) \(assetBalance.asset.code)"
                            )
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .padding()
            .navigationTitle("Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appViewModel.logout()
                    } label: {
                        Image(systemName: "person.slash")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    @ViewBuilder private func info(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(title):")
                .font(.system(size: 10))

            Spacer()

            Text(value)
                .font(.system(size: 14))
                .multilineTextAlignment(.trailing)
        }
    }
}
