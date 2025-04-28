import Foundation
import stellarsdk

class TransactionSender {
    private let accountId: String

    init(accountId: String) {
        self.accountId = accountId
    }
}

extension TransactionSender {
    func paymentOperations(asset: Asset, destinationAccountId: String, amount: Decimal) throws -> [stellarsdk.Operation] {
        guard let asset = stellarsdk.Asset(canonicalForm: asset.id) else {
            throw Kit.SendError.invalidAsset
        }

        let operation = try PaymentOperation(
            sourceAccountId: accountId,
            destinationAccountId: destinationAccountId,
            asset: asset,
            amount: amount
        )

        return [operation]
    }

    func trustlineOperations(asset: Asset, limit: Decimal?) throws -> [stellarsdk.Operation] {
        guard let asset = ChangeTrustAsset(canonicalForm: asset.id) else {
            throw Kit.SendError.invalidAsset
        }

        let operation = ChangeTrustOperation(sourceAccountId: accountId, asset: asset, limit: limit)

        return [operation]
    }
}
