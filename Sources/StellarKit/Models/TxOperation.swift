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
        default: ()
        }

        return tags
    }
}

public extension TxOperation {
    enum `Type`: Codable {
        case accountCreated(data: AccountCreated)
        case payment(data: Payment)
        case changeTrust(data: ChangeTrust)
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
}
