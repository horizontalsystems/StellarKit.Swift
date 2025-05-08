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

    @DistinctPublished private(set) var account: Account?
    @DistinctPublished private(set) var syncState: SyncState = .notSynced(
        error: Kit.SyncError.notStarted)

    private let addedAssetSubject = PassthroughSubject<[Asset], Never>()

    init(accountId: String, api: IApi, storage: AccountStorage, logger: Logger?) throws {
        self.accountId = accountId
        self.api = api
        self.storage = storage
        self.logger = logger

        account = try storage.account()
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

        let oldAssetBalanceMap = account?.assetBalanceMap ?? [:]

        Task { [weak self, accountId, api, oldAssetBalanceMap] in
            do {
                let account = try await api.getAccountDetails(accountId: accountId)

                self?.logger?.log(
                    level: .debug,
                    message: "Got account: \(account.map { "[subentryCount: \($0.subentryCount)] [asset balances: \($0.assetBalanceMap.count)]" } ?? "nil")"
                )

                let newAssetBalanceMap = account?.assetBalanceMap ?? [:]

                self?.account = account

                if let account {
                    try? self?.storage.update(account: account)
                }

                self?.syncState = .synced

                var addedAssets = [Asset]()

                for (asset, assetBalance) in newAssetBalanceMap {
                    if let oldAssetBalance = oldAssetBalanceMap[asset] {
                        if assetBalance.balance > oldAssetBalance.balance {
                            addedAssets.append(asset)
                        }
                    } else if assetBalance.balance > 0 {
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
