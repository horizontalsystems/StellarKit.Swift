import Foundation
import stellarsdk

class StellarApi {
    private let sdk: StellarSDK
    private let testNet: Bool

    private var streamItem: OperationsStreamItem?

    init(sdk: StellarSDK, testNet: Bool) {
        self.sdk = sdk
        self.testNet = testNet
    }
}

extension StellarApi: IApi {
    func getAccountDetails(accountId: String) async throws -> [AssetBalance] {
        let response = await sdk.accounts.getAccountDetails(accountId: accountId)

        switch response {
        case let .success(accountDetails):
            return accountDetails.balances.compactMap { balance -> AssetBalance? in
                guard let decimalBalance = Decimal(string: balance.balance) else {
                    return nil
                }

                let asset: Asset

                switch balance.assetType {
                case AssetTypeAsString.NATIVE:
                    asset = .native
                default:
                    if let code = balance.assetCode, let issuer = balance.assetIssuer {
                        asset = .asset(code: code, issuer: issuer)
                    } else {
                        return nil
                    }
                }

                return AssetBalance(asset: asset, balance: decimalBalance)
            }
        case let .failure(error):
            StellarSDKLog.printHorizonRequestErrorMessage(tag: "account details", horizonRequestError: error)
            throw error
        }
    }

    func getOperations(accountId: String, from cursor: String?, asc: Bool, limit: Int) async throws -> [TxOperation] {
        let response = await sdk.operations.getOperations(
            forAccount: accountId, from: cursor, order: asc ? .ascending : .descending,
            limit: limit, includeFailed: true, join: "transactions"
        )

        switch response {
        case let .success(page):
            return page.records.map { operation in
                var memo: String?

                if let txMemo = operation.transaction?.memo {
                    switch txMemo {
                    case let .text(text): memo = text
                    default: ()
                    }
                }

                return TxOperation(
                    id: operation.id, createdAt: operation.createdAt,
                    pagingToken: operation.pagingToken,
                    sourceAccount: operation.sourceAccount,
                    transactionHash: operation.transactionHash,
                    transactionSuccessful: operation.transactionSuccessful,
                    memo: memo,
                    type: .init(operation: operation)
                )
            }
        case let .failure(error):
            StellarSDKLog.printHorizonRequestErrorMessage(tag: "operations", horizonRequestError: error)
            throw error
        }
    }

    func sendTransaction(keyPair: KeyPair, operations: [stellarsdk.Operation], memo: Memo?) async throws -> String {
        let accountResponse = await sdk.accounts.getAccountDetails(accountId: keyPair.accountId)

        switch accountResponse {
        case let .success(accountResponse):
            let transaction = try Transaction(
                sourceAccount: accountResponse,
                operations: operations,
                memo: memo
            )

            try transaction.sign(keyPair: keyPair, network: testNet ? Network.testnet : Network.public)

            let response = await sdk.transactions.submitTransaction(transaction: transaction)

            switch response {
            case let .success(details):
                return details.id
            case let .destinationRequiresMemo(destinationAccountId):
                throw SendError.destinationRequiresMemo(destinationAccountId: destinationAccountId)
            case let .failure(error):
                StellarSDKLog.printHorizonRequestErrorMessage(tag: "send transaction", horizonRequestError: error)
                throw error
            }
        case let .failure(error):
            StellarSDKLog.printHorizonRequestErrorMessage(tag: "send transaction", horizonRequestError: error)
            throw error
        }
    }
}

extension StellarApi {
    enum SendError: Error {
        case destinationRequiresMemo(destinationAccountId: String)
    }
}

extension TxOperation.`Type` {
    init(operation: OperationResponse) {
        switch operation {
        case let op as AccountCreatedOperationResponse:
            self = .accountCreated(data: .init(
                startingBalance: op.startingBalance,
                funder: op.funder,
                account: op.account
            ))
        case let op as PaymentOperationResponse:
            let asset: Asset

            switch op.assetType {
            case AssetTypeAsString.NATIVE:
                asset = .native
            default:
                asset = .asset(code: op.assetCode ?? "", issuer: op.assetIssuer ?? "")
            }

            self = .payment(data: .init(
                amount: Decimal(string: op.amount) ?? 0,
                asset: asset,
                from: op.from,
                to: op.to
            ))
        default: self = .unknown(rawType: operation.operationTypeString)
        }
    }
}
