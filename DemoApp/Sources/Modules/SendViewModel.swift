import Combine
import Foundation
import StellarKit

class SendViewModel: ObservableObject {
    @Published var asset: Asset = .native

    @Published var address: String = Configuration.shared.defaultSendAddress
    @Published var amount: String = "0.25"
    @Published var memo: String = ""

    @Published var errorAlertText: String?
    @Published var sentAlertText: String?

    init() {}

    var assets: [Asset] {
        guard let stellarKit = Singleton.stellarKit else {
            return []
        }

        return stellarKit.assetBalances.map(\.asset)
    }

    func send() {
        Task { [weak self, asset, address, amount, memo] in
            do {
                guard let stellarKit = Singleton.stellarKit else {
                    throw SendError.noKeyPair
                }

                try StellarKit.Kit.validate(accountId: address)

                guard let decimalAmount = Decimal(string: amount) else {
                    throw SendError.invalidAmount
                }

                let trimmedMemo = memo.trimmingCharacters(in: .whitespaces)
                let memo = trimmedMemo.isEmpty ? nil : memo

                let txId = try await stellarKit.sendPayment(asset: asset, destinationAccountId: address, amount: decimalAmount, memo: memo)

                await MainActor.run { [weak self] in
                    self?.sentAlertText = "You have successfully sent \(decimalAmount) \(asset.code) to \(address) (\(txId))"
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.errorAlertText = "\(error)"
                }
            }
        }
    }
}

extension SendViewModel {
    enum SendError: Error {
        case noKeyPair
        case invalidAmount
    }
}
