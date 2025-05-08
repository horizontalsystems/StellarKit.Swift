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

        migrator.registerMigration("Create account") { db in
            try db.create(table: "account", body: { t in
                t.primaryKey(Account.Columns.uniqueId.name, .text, onConflict: .replace)
                t.column(Account.Columns.subentryCount.name, .integer).notNull()
                t.column(Account.Columns.assetBalanceMap.name, .text).notNull()
            })
        }

        return migrator
    }
}

extension AccountStorage {
    func account() throws -> Account? {
        try dbPool.read { db in
            try Account.fetchOne(db)
        }
    }

    func update(account: Account) throws {
        _ = try dbPool.write { db in
            try account.insert(db)
        }
    }
}
