import Foundation
import stellarsdk

class TransactionSender {
    private let accountId: String

    init(accountId: String) {
        self.accountId = accountId
    }
}

extension TransactionSender {
    func createAccountOperation(destinationAccountId: String, amount: Decimal) throws -> stellarsdk.Operation {
        try CreateAccountOperation(
            sourceAccountId: accountId,
            destinationAccountId: destinationAccountId,
            startBalance: amount
        )
    }

    func paymentOperation(asset: Asset, destinationAccountId: String, amount: Decimal) throws -> stellarsdk.Operation {
        guard let asset = stellarsdk.Asset(canonicalForm: asset.id) else {
            throw Kit.SendError.invalidAsset
        }

        return try PaymentOperation(
            sourceAccountId: accountId,
            destinationAccountId: destinationAccountId,
            asset: asset,
            amount: amount
        )
    }

    func changeTrustOperation(asset: Asset, limit: Decimal?) throws -> stellarsdk.Operation {
        guard let asset = ChangeTrustAsset(canonicalForm: asset.id) else {
            throw Kit.SendError.invalidAsset
        }

        return ChangeTrustOperation(sourceAccountId: accountId, asset: asset, limit: limit)
    }
}
