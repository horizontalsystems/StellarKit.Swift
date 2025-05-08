import Foundation
import GRDB

public struct Account: Codable, Equatable, Hashable {
    let uniqueId: String
    public let subentryCount: UInt
    public let assetBalanceMap: [Asset: AssetBalance]

    init(subentryCount: UInt, assetBalanceMap: [Asset: AssetBalance]) {
        uniqueId = "uniqueId"
        self.subentryCount = subentryCount
        self.assetBalanceMap = assetBalanceMap
    }

    public var lockedBalance: Decimal {
        1 + 0.5 * Decimal(subentryCount)
    }

    public var nativeBalance: Decimal {
        assetBalanceMap[.native]?.balance ?? 0
    }

    public var availableBalance: Decimal {
        max(0, nativeBalance - lockedBalance)
    }
}

extension Account: FetchableRecord, PersistableRecord {
    enum Columns {
        static let uniqueId = Column(CodingKeys.uniqueId)
        static let subentryCount = Column(CodingKeys.subentryCount)
        static let assetBalanceMap = Column(CodingKeys.assetBalanceMap)
    }
}
