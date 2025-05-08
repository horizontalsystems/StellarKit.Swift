import Foundation

public struct AssetBalance: Codable, Equatable, Hashable {
    public let asset: Asset
    public let balance: Decimal
    public let limit: Decimal?

    init(asset: Asset, balance: Decimal, limit: Decimal?) {
        self.asset = asset
        self.balance = balance
        self.limit = limit
    }
}
