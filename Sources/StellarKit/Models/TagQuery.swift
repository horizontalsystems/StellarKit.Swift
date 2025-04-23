public class TagQuery {
    public let type: Tag.`Type`?
    public let assetId: String?
    public let accountId: String?

    public init(type: Tag.`Type`? = nil, assetId: String? = nil, accountId: String? = nil) {
        self.type = type
        self.assetId = assetId
        self.accountId = accountId
    }

    var isEmpty: Bool {
        type == nil && assetId == nil && accountId == nil
    }
}
