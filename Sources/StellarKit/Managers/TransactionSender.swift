import Foundation
import HsToolKit
import stellarsdk

class TransactionSender {
    private let keyPair: KeyPair
    private let api: IApi
    private let logger: Logger?

    init(keyPair: KeyPair, api: IApi, logger: Logger?) {
        self.keyPair = keyPair
        self.api = api
        self.logger = logger
    }
}

extension TransactionSender {
    func sendPayment(asset: Asset, destinationAccountId: String, amount: Decimal, memo: String?) async throws -> String {
        guard let asset = stellarsdk.Asset(canonicalForm: asset.id) else {
            throw Kit.SendError.invalidAsset
        }

        let operation = try PaymentOperation(
            sourceAccountId: keyPair.accountId,
            destinationAccountId: destinationAccountId,
            asset: asset,
            amount: amount
        )

        let memo: Memo = memo.map { Memo.text($0) } ?? Memo.none

        return try await api.sendTransaction(keyPair: keyPair, operations: [operation], memo: memo)
    }

    func sendTrustline(asset: Asset, limit: Decimal?) async throws -> String {
        guard let asset = ChangeTrustAsset(canonicalForm: asset.id) else {
            throw Kit.SendError.invalidAsset
        }

        let operation = ChangeTrustOperation(sourceAccountId: keyPair.accountId, asset: asset, limit: limit)

        return try await api.sendTransaction(keyPair: keyPair, operations: [operation], memo: Memo.none)
    }
}
