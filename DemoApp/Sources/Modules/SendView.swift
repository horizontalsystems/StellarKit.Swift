import SwiftUI
import UIKit

struct SendView: View {
    @StateObject private var viewModel = SendViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Text("Asset")

                    Spacer()

                    Picker("Asset", selection: $viewModel.asset) {
                        ForEach(viewModel.assets, id: \.self) { asset in
                            Text(asset.code)
                        }
                    }
                }

                TextField("Address", text: $viewModel.address, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3)

                TextField("Amount", text: $viewModel.amount, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1)

                TextField("Memo", text: $viewModel.memo, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3)

                Button("Send") {
                    viewModel.send()
                }

                Spacer()
            }
            .padding()
            .alert(item: $viewModel.errorAlertText) { text in
                Alert(title: Text("Error"), message: Text(text), dismissButton: .cancel(Text("Got It")))
            }
            .alert(item: $viewModel.sentAlertText) { text in
                Alert(title: Text("Sent"), message: Text(text), dismissButton: .cancel(Text("Got It")))
            }
            .navigationTitle("Send")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
