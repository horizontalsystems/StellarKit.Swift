import Foundation
import GRDB

public struct OperationInfo {
    public let operations: [TxOperation]
    public let initial: Bool
}

public struct TxOperation: Codable {
    public let id: String
    public let createdAt: Date
    public let pagingToken: String
    public let sourceAccount: String
    public let transactionHash: String
    public let transactionSuccessful: Bool
    public let memo: String?
    public let feeCharged: Decimal?
    public let type: Type

    func tags(accountId: String) -> [Tag] {
        var tags = [Tag]()

        switch type {
        case let .accountCreated(data):
            if data.funder == accountId {
                tags.append(Tag(operationId: id, type: .outgoing, assetId: Asset.native.id, accountIds: [data.account]))
            }

            if data.account == accountId {
                tags.append(Tag(operationId: id, type: .incoming, assetId: Asset.native.id, accountIds: [data.funder]))
            }
        case let .payment(data):
            if data.from == accountId {
                tags.append(Tag(operationId: id, type: .outgoing, assetId: data.asset.id, accountIds: [data.to]))
            }

            if data.to == accountId {
                tags.append(Tag(operationId: id, type: .incoming, assetId: data.asset.id, accountIds: [data.from]))
            }
        case let .pathPayment(data):
            // A swap settling on the own account (from == to == accountId) yields both tags,
            // so it shows in the source asset's list (outgoing) AND the destination's (incoming).
            if data.from == accountId {
                tags.append(Tag(operationId: id, type: .outgoing, assetId: data.sourceAsset.id, accountIds: [data.to]))
            }

            if data.to == accountId {
                tags.append(Tag(operationId: id, type: .incoming, assetId: data.asset.id, accountIds: [data.from]))
            }
        case let .changeTrust(data):
            if data.trustor == accountId {
                tags.append(Tag(operationId: id, type: .outgoing, assetId: data.asset.id, accountIds: data.trustee.map { [$0] } ?? []))
            }
        case let .invokeHostFunction(data):
            // Soroban contract invocation (DEX aggregators, SAC transfers): tag from the
            // per-asset balance changes that touch this account, merged per direction.
            var outgoing = [String: Set<String>]()
            var incoming = [String: Set<String>]()

            for change in data.balanceChanges {
                if change.from == accountId {
                    outgoing[change.asset.id, default: []].formUnion(change.to.map { [$0] } ?? [])
                }
                if change.to == accountId {
                    incoming[change.asset.id, default: []].formUnion(change.from.map { [$0] } ?? [])
                }
            }

            for (assetId, accounts) in outgoing {
                tags.append(Tag(operationId: id, type: .outgoing, assetId: assetId, accountIds: Array(accounts)))
            }
            for (assetId, accounts) in incoming {
                tags.append(Tag(operationId: id, type: .incoming, assetId: assetId, accountIds: Array(accounts)))
            }
        case .unknown: ()
        }

        return tags
    }
}

public extension TxOperation {
    enum `Type`: Codable {
        case accountCreated(data: AccountCreated)
        case payment(data: Payment)
        case pathPayment(data: PathPayment)
        case changeTrust(data: ChangeTrust)
        case invokeHostFunction(data: InvokeHostFunction)
        case unknown(rawType: String)
    }
}

extension TxOperation: FetchableRecord, PersistableRecord {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let createdAt = Column(CodingKeys.createdAt)
        static let pagingToken = Column(CodingKeys.pagingToken)
        static let sourceAccount = Column(CodingKeys.sourceAccount)
        static let transactionHash = Column(CodingKeys.transactionHash)
        static let transactionSuccessful = Column(CodingKeys.transactionSuccessful)
        static let memo = Column(CodingKeys.memo)
        static let feeCharged = Column(CodingKeys.feeCharged)
        static let type = Column(CodingKeys.type)
    }
}

public extension TxOperation {
    struct AccountCreated: Codable {
        public let startingBalance: Decimal
        public let funder: String
        public let account: String
    }

    struct Payment: Codable {
        public let amount: Decimal
        public let asset: Asset
        public let from: String
        public let to: String
    }

    struct ChangeTrust: Codable {
        public let trustor: String
        public let trustee: String?
        public let asset: Asset
        public let limit: Decimal
        public let liquidityPoolId: String?
    }

    /// path_payment_strict_send / path_payment_strict_receive — an atomic swap through the
    /// SDEX order book and/or liquidity pools. `sourceAsset`/`sourceAmount` is what `from`
    /// spent; `asset`/`amount` is what `to` received.
    struct PathPayment: Codable {
        public let sourceAmount: Decimal
        public let sourceAsset: Asset
        public let amount: Decimal
        public let asset: Asset
        public let from: String
        public let to: String
    }

    /// invoke_host_function — a Soroban contract invocation (DEX aggregator swaps, SAC
    /// transfers). Horizon reports the classic-asset movements as balance changes; that is
    /// the account-relevant payload (contract-internal tokens without a classic twin are
    /// not covered by Horizon and thus not here).
    struct InvokeHostFunction: Codable {
        public let function: String
        public let balanceChanges: [BalanceChange]
    }

    struct BalanceChange: Codable {
        public let type: String // transfer | mint | burn | clawback
        public let asset: Asset
        public let from: String?
        public let to: String?
        public let amount: Decimal
    }
}
