import Combine
import HsExtensions
import HsToolKit

class OperationManager {
    private static let limit = 200

    private let accountId: String
    private let api: IApi
    private let storage: OperationStorage
    private let logger: Logger?

    private var tasks = Set<AnyTask>()

    @DistinctPublished private(set) var syncState: SyncState = .notSynced(
        error: Kit.SyncError.notStarted)

    private let operationSubject = PassthroughSubject<OperationInfoWithTags, Never>()

    init(accountId: String, api: IApi, storage: OperationStorage, logger: Logger?) {
        self.accountId = accountId
        self.api = api
        self.storage = storage
        self.logger = logger
    }

    private func handle(operations: [TxOperation], initial: Bool) {
        guard !operations.isEmpty else {
            return
        }

        try? storage.save(operations: operations)

        let operationsWithTags = operations.map { operation in
            OperationWithTags(operation: operation, tags: operation.tags(accountId: accountId))
        }

        let tags = operationsWithTags.map(\.tags).flatMap { $0 }
        try? storage.save(tags: tags)

        operationSubject.send(OperationInfoWithTags(operations: operationsWithTags, initial: initial))
    }
}

extension OperationManager {
    func operation(id: String) -> TxOperation? {
        do {
            return try storage.operation(id: id)
        } catch {
            return nil
        }
    }

    func operations(tagQuery: TagQuery, pagingToken: String?, limit: Int?) -> [TxOperation] {
        do {
            return try storage.operations(tagQuery: tagQuery, pagingToken: pagingToken, limit: limit ?? 100)
        } catch {
            return []
        }
    }

    func operationPublisher(tagQuery: TagQuery) -> AnyPublisher<OperationInfo, Never> {
        if tagQuery.isEmpty {
            return operationSubject
                .map { info in
                    OperationInfo(
                        operations: info.operations.map(\.operation),
                        initial: info.initial
                    )
                }
                .eraseToAnyPublisher()
        } else {
            return operationSubject
                .map { info in
                    OperationInfo(
                        operations: info.operations.compactMap { operationWithTags -> TxOperation? in
                            for tag in operationWithTags.tags {
                                if tag.conforms(tagQuery: tagQuery) {
                                    return operationWithTags.operation
                                }
                            }

                            return nil
                        },
                        initial: info.initial
                    )
                }
                .filter { info in
                    !info.operations.isEmpty
                }
                .eraseToAnyPublisher()
        }
    }

    func assets() -> [Asset] {
        do {
            return try storage.assetIds().map { Asset(id: $0) }
        } catch {
            return []
        }
    }

    func sync() {
        logger?.log(level: .debug, message: "Syncing operations...")

        guard !syncState.syncing else {
            logger?.log(level: .debug, message: "Already syncing operations")
            return
        }

        syncState = .syncing

        Task { [weak self, accountId, api, storage] in
            do {
                let latestOperation = try storage.latestOperation()

                if let latestOperation {
                    self?.logger?.log(level: .debug, message: "Fetching latest operations...")

                    var pagingToken: String? = latestOperation.pagingToken

                    repeat {
                        let operations = try await api.getOperations(
                            accountId: accountId, from: pagingToken, asc: true, limit: Self.limit
                        )

                        self?.logger?.log(
                            level: .debug,
                            message:
                            "Got latest operations: \(operations.count), pagingToken: \(pagingToken ?? "null")"
                        )

                        self?.handle(operations: operations, initial: false)

                        if operations.count < Self.limit {
                            break
                        }

                        pagingToken = operations.last?.pagingToken
                    } while true
                }

                let operationSyncState = try storage.operationSyncState()
                let allSynced = operationSyncState?.allSynced ?? false

                if !allSynced {
                    self?.logger?.log(level: .debug, message: "Fetching history operations...")

                    let oldestOperation = try storage.oldestOperation()
                    var pagingToken = oldestOperation?.pagingToken

                    var pages = 0

                    repeat {
                        let operations = try await api.getOperations(accountId: accountId, from: pagingToken, asc: false, limit: Self.limit)

                        self?.logger?.log(
                            level: .debug,
                            message:
                            "Got history operations: \(operations.count), pagingToken: \(pagingToken ?? "null")"
                        )

                        self?.handle(operations: operations, initial: true)

                        if operations.count < Self.limit || pages > 10 { // TODO: decide max page number to fetch
                            break
                        }

                        pagingToken = operations.last?.pagingToken
                        pages += 1
                    } while true

                    let newOldestOperation = try storage.oldestOperation()

                    if newOldestOperation != nil {
                        try? storage.save(operationSyncState: .init(allSynced: true))
                    }
                }

                self?.syncState = .synced
            } catch {
                self?.logger?.log(level: .error, message: "Operation sync error: \(error)")
                self?.syncState = .notSynced(error: error)
            }
        }.store(in: &tasks)
    }
}

extension OperationManager {
    private struct OperationWithTags {
        let operation: TxOperation
        let tags: [Tag]
    }

    private struct OperationInfoWithTags {
        let operations: [OperationWithTags]
        let initial: Bool
    }
}
