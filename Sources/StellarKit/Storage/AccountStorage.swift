import Foundation
import GRDB

class AccountStorage {
    private let dbPool: DatabasePool

    init(dbPool: DatabasePool) throws {
        self.dbPool = dbPool

        try migrator.migrate(dbPool)
    }

    var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("Create assetBalance") { db in
            try db.create(table: "assetBalance", body: { t in
                t.primaryKey(AssetBalance.Columns.asset.name, .text, onConflict: .replace)
                t.column(AssetBalance.Columns.balance.name, .text).notNull()
            })
        }

        return migrator
    }
}

extension AccountStorage {
    func assetBalances() throws -> [AssetBalance] {
        try dbPool.read { db in
            try AssetBalance.fetchAll(db)
        }
    }

    func update(assetBalances: [AssetBalance]) throws {
        _ = try dbPool.write { db in
            try AssetBalance.deleteAll(db)

            for assetBalance in assetBalances {
                try assetBalance.insert(db)
            }
        }
    }
}
