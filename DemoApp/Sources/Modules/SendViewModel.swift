import Combine
import Foundation
import StellarKit
import stellarsdk

class SendViewModel: ObservableObject {
    @Published var asset: StellarKit.Asset = .native

    @Published var address: String = Configuration.shared.defaultSendAddress
    @Published var amount: String = "0.25"
    @Published var memo: String = ""

    @Published var errorAlertText: String?
    @Published var sentAlertText: String?

    init() {}

    var assets: [StellarKit.Asset] {
        guard let stellarKit = Singleton.stellarKit else {
            return []
        }

        return stellarKit.account.map { Array($0.assetBalanceMap.keys) } ?? []
    }

    func send() {
        Task { [weak self, asset, address, amount, memo] in
            do {
                guard let stellarKit = Singleton.stellarKit, let keyPair = Singleton.keyPair else {
                    throw SendError.noKeyPair
                }

                guard let account = stellarKit.account else {
                    throw SendError.noAccount
                }

                try StellarKit.Kit.validate(accountId: address)

                guard let decimalAmount = Decimal(string: amount) else {
                    throw SendError.invalidAmount
                }

                guard decimalAmount <= account.availableBalance else {
                    throw SendError.moreThanAvailableBalance
                }

                let trimmedMemo = memo.trimmingCharacters(in: .whitespaces)
                let memo: Memo = trimmedMemo.isEmpty ? .none : .text(memo)

                let operations = try stellarKit.paymentOperations(asset: asset, destinationAccountId: address, amount: decimalAmount)
                let txId = try await StellarKit.Kit.send(operations: operations, memo: memo, keyPair: keyPair, testNet: Configuration.shared.testNet)

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
        case noAccount
        case invalidAmount
        case moreThanAvailableBalance
    }
}
