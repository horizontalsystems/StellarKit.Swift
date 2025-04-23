import Foundation
import GRDB

struct OperationSyncState: Codable {
    let id: String
    let allSynced: Bool

    init(allSynced: Bool) {
        id = "unique_id"
        self.allSynced = allSynced
    }
}

extension OperationSyncState: FetchableRecord, PersistableRecord {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let allSynced = Column(CodingKeys.allSynced)
    }
}
