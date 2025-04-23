import GRDB

public class Tag: Codable {
    public let operationId: String
    public let type: `Type`?
    public let assetId: String?
    public let accountIds: [String]

    public init(operationId: String, type: Type? = nil, assetId: String? = nil, accountIds: [String] = []) {
        self.operationId = operationId
        self.type = type
        self.assetId = assetId
        self.accountIds = accountIds
    }

    public func conforms(tagQuery: TagQuery) -> Bool {
        if let type = tagQuery.type, self.type != type {
            return false
        }

        if let assetId = tagQuery.assetId, self.assetId != assetId {
            return false
        }

        if let accountId = tagQuery.accountId, !accountIds.contains(accountId) {
            return false
        }

        return true
    }
}

extension Tag: FetchableRecord, PersistableRecord {
    enum Columns {
        static let operationId = Column(CodingKeys.operationId)
        static let type = Column(CodingKeys.type)
        static let assetId = Column(CodingKeys.assetId)
        static let accountIds = Column(CodingKeys.accountIds)
    }
}

public extension Tag {
    enum `Type`: String, Codable {
        case incoming
        case outgoing
        case swap
        case unsupported
    }
}
