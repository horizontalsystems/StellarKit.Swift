import Combine
import Foundation
import stellarsdk

class StellarApi {
    private let sdk: StellarSDK
    private let testNet: Bool

    private let operationSubject = PassthroughSubject<TxOperation, Never>()

    private var streamItem: OperationsStreamItem?

    init(sdk: StellarSDK, testNet: Bool) {
        self.sdk = sdk
        self.testNet = testNet
    }

    deinit {
        streamItem?.closeStream()
    }

    private func handle(operationResponse: OperationResponse) {
        operationSubject.send(txOperation(operationResponse: operationResponse))
    }

    private func txOperation(operationResponse operation: OperationResponse) -> TxOperation {
        var memo: String?
        var feeCharged: Decimal?

        if let transaction = operation.transaction {
            if let txMemo = transaction.memo {
                switch txMemo {
                case let .text(text): memo = text
                default: ()
                }
            }

            if let txFeeCharged = transaction.feeCharged, let decimal = Decimal(string: txFeeCharged) {
                feeCharged = decimal / 10_000_000
            }
        }

        return TxOperation(
            id: operation.id, createdAt: operation.createdAt,
            pagingToken: operation.pagingToken,
            sourceAccount: operation.sourceAccount,
            transactionHash: operation.transactionHash,
            transactionSuccessful: operation.transactionSuccessful,
            memo: memo,
            feeCharged: feeCharged,
            type: .init(operation: operation)
        )
    }
}

extension StellarApi: IApi {
    func getAccountDetails(accountId: String) async throws -> Account? {
        let response = await sdk.accounts.getAccountDetails(accountId: accountId)

        switch response {
        case let .success(accountDetails):
            let assetBalances = accountDetails.balances.compactMap { balance -> AssetBalance? in
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

                return AssetBalance(asset: asset, balance: decimalBalance, limit: balance.limit.flatMap { Decimal(string: $0) })
            }

            return Account(
                subentryCount: accountDetails.subentryCount,
                assetBalanceMap: assetBalances.reduce(into: [:]) { $0[$1.asset] = $1 }
            )
        case let .failure(error):
            StellarSDKLog.printHorizonRequestErrorMessage(tag: "account details", horizonRequestError: error)

            switch error {
            case .notFound:
                return nil
            default:
                throw error
            }
        }
    }

    func getOperations(accountId: String, from cursor: String?, asc: Bool, limit: Int) async throws -> [TxOperation] {
        let response = await sdk.operations.getOperations(
            forAccount: accountId, from: cursor, order: asc ? .ascending : .descending,
            limit: limit, includeFailed: true, join: "transactions"
        )

        switch response {
        case let .success(page):
            return page.records.map { operationResponse in
                txOperation(operationResponse: operationResponse)
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

extension StellarApi: IApiListener {
    func start(accountId: String) {
        streamItem = sdk.operations.stream(for: .operationsForAccount(account: accountId, cursor: "now"))

        streamItem?.onReceive { [weak self] response in
            switch response {
            case .open:
                break
            case let .response(_, operationResponse):
                self?.handle(operationResponse: operationResponse)
            case let .error(err):
                print("Stream Error (\(accountId)): \(err?.localizedDescription ?? "nil")")

                // self?.stop()
                // self?.start(accountId: accountId)
            }
        }
    }

    func stop() {
        streamItem?.closeStream()
        streamItem = nil
    }

    var started: Bool {
        streamItem != nil
    }

    var operationPublisher: AnyPublisher<TxOperation, Never> {
        operationSubject.eraseToAnyPublisher()
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
            self = .payment(data: .init(
                amount: Decimal(string: op.amount) ?? 0,
                asset: Self.asset(type: op.assetType, code: op.assetCode, issuer: op.assetIssuer),
                from: op.from,
                to: op.to
            ))
        case let op as ChangeTrustOperationResponse:
            self = .changeTrust(data: .init(
                trustor: op.trustor,
                trustee: op.trustee,
                asset: Self.asset(type: op.assetType, code: op.assetCode, issuer: op.assetIssuer),
                limit: op.limit.flatMap { Decimal(string: $0) } ?? 0,
                liquidityPoolId: op.liquidityPoolId
            ))
        default:
            self = .unknown(rawType: operation.operationTypeString.components(separatedBy: "_").map(\.capitalized).joined(separator: " "))
        }
    }

    private static func asset(type: String, code: String?, issuer: String?) -> Asset {
        switch type {
        case AssetTypeAsString.NATIVE:
            return .native
        default:
            return .asset(code: code ?? "", issuer: issuer ?? "")
        }
    }
}
