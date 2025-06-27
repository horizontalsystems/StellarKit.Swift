import Foundation
import GRDB

class OperationStorage {
    private let dbPool: DatabasePool

    init(dbPool: DatabasePool) throws {
        self.dbPool = dbPool

        try migrator.migrate(dbPool)
    }

    var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("Create operationSyncState") { db in
            try db.create(
                table: "operationSyncState",
                body: { t in
                    t.primaryKey(OperationSyncState.Columns.id.name, .text, onConflict: .replace)
                    t.column(OperationSyncState.Columns.allSynced.name, .boolean).notNull()
                }
            )
        }

        migrator.registerMigration("Create txOperation") { db in
            try db.create(
                table: "txOperation",
                body: { t in
                    t.primaryKey(TxOperation.Columns.id.name, .text, onConflict: .replace)
                    t.column(TxOperation.Columns.createdAt.name, .date).notNull()
                    t.column(TxOperation.Columns.pagingToken.name, .text).notNull()
                    t.column(TxOperation.Columns.sourceAccount.name, .text).notNull()
                    t.column(TxOperation.Columns.transactionHash.name, .text).notNull()
                    t.column(TxOperation.Columns.transactionSuccessful.name, .boolean).notNull()
                    t.column(TxOperation.Columns.memo.name, .text)
                    t.column(TxOperation.Columns.feeCharged.name, .text)
                    t.column(TxOperation.Columns.type.name, .text).notNull()
                }
            )
        }

        migrator.registerMigration("Create tag") { db in
            try db.create(
                table: "tag",
                body: { t in
                    t.column(Tag.Columns.operationId.name, .text).notNull()
                    t.column(Tag.Columns.type.name, .text)
                    t.column(Tag.Columns.assetId.name, .text)
                    t.column(Tag.Columns.accountIds.name, .text).notNull()
                }
            )
        }

        return migrator
    }
}

extension OperationStorage {
    func operationSyncState() throws -> OperationSyncState? {
        try dbPool.read { db in
            try OperationSyncState.fetchOne(db)
        }
    }

    func operations(tagQuery: TagQuery, pagingToken: String?, descending: Bool, limit: Int?) throws -> [TxOperation] {
        try dbPool.read { db in
            var arguments = [DatabaseValueConvertible]()
            var whereConditions = [String]()
            var joinClause = ""

            if !tagQuery.isEmpty {
                if let type = tagQuery.type {
                    whereConditions.append("tag.'\(Tag.Columns.type.name)' = ?")
                    arguments.append(type.rawValue)
                }
                if let assetId = tagQuery.assetId {
                    whereConditions.append("tag.'\(Tag.Columns.assetId.name)' = ?")
                    arguments.append(assetId)
                }
                if let accountId = tagQuery.accountId {
                    whereConditions.append("LOWER(tag.'\(Tag.Columns.accountIds.name)') LIKE ?")
                    arguments.append("%" + accountId + "%")
                }

                joinClause = "INNER JOIN tag ON txOperation.\(TxOperation.Columns.id.name) = tag.\(Tag.Columns.operationId.name)"
            }

            if let pagingToken {
                whereConditions.append("txOperation.\(TxOperation.Columns.pagingToken.name) \(descending ? "<" : ">") ?")
                arguments.append(pagingToken)
            }

            var limitClause = ""
            if let limit {
                limitClause = "LIMIT \(limit)"
            }
            let orderClause = "ORDER BY txOperation.\(TxOperation.Columns.pagingToken.name) \(descending ? "DESC" : "ASC")"
            let whereClause = whereConditions.count > 0 ? "WHERE \(whereConditions.joined(separator: " AND "))" : ""

            let sql = """
            SELECT DISTINCT txOperation.*
            FROM txOperation
            \(joinClause)
            \(whereClause)
            \(orderClause)
            \(limitClause)
            """

            let rows = try Row.fetchAll(db.makeStatement(sql: sql), arguments: StatementArguments(arguments))
            return try rows.map { row -> TxOperation in
                try TxOperation(row: row)
            }
        }
    }

    func operation(id: String) throws -> TxOperation? {
        try dbPool.read { db in
            try TxOperation
                .filter(TxOperation.Columns.id == id)
                .fetchOne(db)
        }
    }

    func operations(ids: [String]) throws -> [TxOperation] {
        try dbPool.read { db in
            try TxOperation
                .filter(ids.contains(TxOperation.Columns.id))
                .fetchAll(db)
        }
    }

    func latestOperation() throws -> TxOperation? {
        try dbPool.read { db in
            try TxOperation
                .order(TxOperation.Columns.createdAt.desc)
                .limit(1)
                .fetchOne(db)
        }
    }

    func oldestOperation() throws -> TxOperation? {
        try dbPool.read { db in
            try TxOperation
                .order(TxOperation.Columns.createdAt.asc)
                .limit(1)
                .fetchOne(db)
        }
    }

    func assetIds() throws -> [String] {
        try dbPool.write { db in
            let request = Tag
                .filter(Tag.Columns.assetId != nil)
                .select(Tag.Columns.assetId)
                .distinct()
            let rows = try Row.fetchAll(db, request)

            return rows.compactMap { row in
                row[0]
            }
        }
    }

    func save(operationSyncState: OperationSyncState) throws {
        _ = try dbPool.write { db in
            try operationSyncState.insert(db)
        }
    }

    func save(operations: [TxOperation]) throws {
        _ = try dbPool.write { db in
            for operation in operations {
                try operation.insert(db)
            }
        }
    }

    func save(tags: [Tag]) throws {
        _ = try dbPool.write { db in
            for tag in tags {
                try tag.insert(db)
            }
        }
    }
}
