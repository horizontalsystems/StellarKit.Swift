import Foundation
import HsExtensions
import HsToolKit

class AccountManager {
    private let accountId: String
    private let api: IApi
    private let storage: AccountStorage
    private let logger: Logger?

    private var tasks = Set<AnyTask>()

    @DistinctPublished private(set) var assetBalances: [Asset: Decimal]
    @DistinctPublished private(set) var syncState: SyncState = .notSynced(
        error: Kit.SyncError.notStarted)

    init(accountId: String, api: IApi, storage: AccountStorage, logger: Logger?) throws {
        self.accountId = accountId
        self.api = api
        self.storage = storage
        self.logger = logger

        assetBalances = try storage.assetBalances().reduce(into: [:]) { $0[$1.asset] = $1.balance }
    }
}

extension AccountManager {
    func sync() {
        logger?.log(level: .debug, message: "Syncing account...")

        guard !syncState.syncing else {
            logger?.log(level: .debug, message: "Already syncing account")
            return
        }

        syncState = .syncing

        Task { [weak self, accountId, api] in
            do {
                let assetBalances = try await api.getAccountDetails(accountId: accountId)
                self?.logger?.log(
                    level: .debug,
                    message: "Got account asset balances: \(assetBalances.count)"
                )

                self?.assetBalances = assetBalances.reduce(into: [:]) { $0[$1.asset] = $1.balance }

                try? self?.storage.update(assetBalances: assetBalances)

                self?.syncState = .synced
            } catch {
                self?.logger?.log(level: .error, message: "Account sync error: \(error)")
                self?.syncState = .notSynced(error: error)
            }
        }.store(in: &tasks)
    }
}
