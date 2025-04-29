import Combine
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

    private let addedAssetSubject = PassthroughSubject<[Asset], Never>()

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

        let oldAssetBalances = assetBalances

        Task { [weak self, accountId, api, oldAssetBalances] in
            do {
                let assetBalances = try await api.getAccountDetails(accountId: accountId)
                self?.logger?.log(
                    level: .debug,
                    message: "Got account asset balances: \(assetBalances.count)"
                )

                let newAssetBalances = assetBalances.reduce(into: [:]) { $0[$1.asset] = $1.balance }

                self?.assetBalances = newAssetBalances

                try? self?.storage.update(assetBalances: assetBalances)

                self?.syncState = .synced

                var addedAssets = [Asset]()

                for (asset, balance) in newAssetBalances {
                    if let oldBalance = oldAssetBalances[asset] {
                        if balance > oldBalance {
                            addedAssets.append(asset)
                        }
                    } else if balance > 0 {
                        addedAssets.append(asset)
                    }
                }

                if !addedAssets.isEmpty {
                    self?.addedAssetSubject.send(addedAssets)
                }
            } catch {
                self?.logger?.log(level: .error, message: "Account sync error: \(error)")
                self?.syncState = .notSynced(error: error)
            }
        }.store(in: &tasks)
    }

    var addedAssetPublisher: AnyPublisher<[Asset], Never> {
        addedAssetSubject.eraseToAnyPublisher()
    }
}
