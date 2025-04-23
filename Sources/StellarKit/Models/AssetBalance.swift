import Foundation
import GRDB

public struct AssetBalance: Codable, Equatable, Hashable {
    public let asset: Asset
    public let balance: Decimal

    init(asset: Asset, balance: Decimal) {
        self.asset = asset
        self.balance = balance
    }
}

extension AssetBalance: FetchableRecord, PersistableRecord {
    enum Columns {
        static let asset = Column(CodingKeys.asset)
        static let balance = Column(CodingKeys.balance)
    }
}
