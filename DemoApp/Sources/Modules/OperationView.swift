import SwiftUI

struct OperationView: View {
    @StateObject private var viewModel = OperationViewModel()
    @ObservedObject private var appViewModel: AppViewModel

    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Type")

                        Spacer()

                        Picker("Operation Type", selection: $viewModel.operationType) {
                            ForEach(OperationViewModel.OperationType.allCases, id: \.self) { operationType in
                                Text(operationType.rawValue.capitalized)
                            }
                        }
                    }

                    HStack {
                        Text("Asset")

                        Spacer()

                        Picker("Operation Asset", selection: $viewModel.operationAsset) {
                            ForEach(viewModel.operationAssets, id: \.self) { operationAsset in
                                Text(operationAsset.title)
                            }
                        }
                    }

                    TextField("Account Id", text: $viewModel.operationAccountId, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3)
                        .padding(.top, 8)
                }
                .font(.system(size: 14))
                .padding()

                Divider()

                List {
                    ForEach(viewModel.operations, id: \.id) { operation in
                        VStack {
                            info(title: "Id", value: operation.id)
                            info(title: "Created At", value: operation.createdAt.formatted(date: .abbreviated, time: .standard))
                            info(title: "Paging Token", value: "\(operation.pagingToken)")
                            info(title: "Source", value: "\(operation.sourceAccount)")
                            info(title: "Tx Hash", value: "\(operation.transactionHash)")
                            info(title: "Tx Successful", value: "\(operation.transactionSuccessful)")

                            if let memo = operation.memo {
                                info(title: "Memo", value: "\(memo)")
                            }

                            switch operation.type {
                            case let .accountCreated(data):
                                actionTitle(text: "Account Created")
                                info(title: "Starting Balance", value: "\(data.startingBalance)")
                                info(title: "Funder", value: "\(data.funder)")
                                info(title: "Account", value: "\(data.account)")
                            case let .payment(data):
                                actionTitle(text: "Payment")
                                info(title: "Amount", value: "\(data.amount)")
                                info(title: "Asset", value: "\(data.asset.id)")
                                info(title: "From", value: "\(data.from)")
                                info(title: "To", value: "\(data.to)")
                            case let .changeTrust(data):
                                actionTitle(text: "Change Trust")
                                info(title: "Trustor", value: "\(data.trustor)")
                                info(title: "Trustee", value: "\(data.trustee ?? "nil")")
                                info(title: "Asset", value: "\(data.asset.id)")
                                info(title: "Limit", value: "\(data.limit)")
                                info(title: "Liquidity Pool Id", value: "\(data.liquidityPoolId ?? "nil")")
                            case let .unknown(rawType):
                                actionTitle(text: rawType)
                            }
                        }
                        .listRowSeparator(.hidden)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.gray.opacity(0.2), lineWidth: 1))
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: .infinity)
            }
            .navigationTitle("Operations")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder private func info(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(title):")
                .font(.system(size: 12))

            Spacer()

            Text(value)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.middle)
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder private func actionTitle(text: String) -> some View {
        Text("[ \(text) ]")
            .font(.system(size: 12))
            .padding(.bottom, 8)
    }
}
