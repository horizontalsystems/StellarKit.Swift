import Combine
import Foundation
import GRDB
import HsExtensions
import HsToolKit
import stellarsdk

public class Kit {
    private let accountId: String

    private let accountManager: AccountManager
    private let operationManager: OperationManager
    private let transactionSender: TransactionSender?
    private let logger: Logger?

    private var cancellables = Set<AnyCancellable>()
    private var tasks = Set<AnyTask>()

    init(accountId: String, accountManager: AccountManager, operationManager: OperationManager, transactionSender: TransactionSender?, logger: Logger?) {
        self.accountId = accountId
        self.accountManager = accountManager
        self.operationManager = operationManager
        self.transactionSender = transactionSender
        self.logger = logger
    }
}

public extension Kit {
    var syncState: SyncState {
        accountManager.syncState
    }

    var syncStatePublisher: AnyPublisher<SyncState, Never> {
        accountManager.$syncState.eraseToAnyPublisher()
    }

    var operationSyncState: SyncState {
        operationManager.syncState
    }

    var operationSyncStatePublisher: AnyPublisher<SyncState, Never> {
        operationManager.$syncState.eraseToAnyPublisher()
    }

    var assetBalances: [AssetBalance] {
        accountManager.assetBalances
    }

    var assetBalancePublisher: AnyPublisher<[AssetBalance], Never> {
        accountManager.$assetBalances.eraseToAnyPublisher()
    }

    var receiveAddress: String {
        accountId
    }

    func operations(tagQuery: TagQuery, pagingToken: String? = nil, limit: Int? = nil)
        -> [TxOperation]
    {
        operationManager.operations(tagQuery: tagQuery, pagingToken: pagingToken, limit: limit)
    }

    func operationPublisher(tagQuery: TagQuery) -> AnyPublisher<OperationInfo, Never> {
        operationManager.operationPublisher(tagQuery: tagQuery)
    }

    func operationAssets() -> [Asset] {
        operationManager.assets()
    }

    func sync() {
        accountManager.sync()
        operationManager.sync()
    }

    func sendPayment(asset: Asset, destinationAccountId: String, amount: Decimal, memo: String?) async throws -> String {
        guard let transactionSender else {
            throw SendError.noTransactionSender
        }

        return try await transactionSender.sendPayment(asset: asset, destinationAccountId: destinationAccountId, amount: amount, memo: memo)
    }

    func sendTrustline(asset: Asset, limit: Decimal?) async throws -> String {
        guard let transactionSender else {
            throw SendError.noTransactionSender
        }

        return try await transactionSender.sendTrustline(asset: asset, limit: limit)
    }

    static func validate(accountId: String) throws {
        _ = try PublicKey(accountId: accountId)
    }
}

extension Kit {
    public static func clear(exceptFor excludedFiles: [String]) throws {
        let fileManager = FileManager.default
        let fileUrls = try fileManager.contentsOfDirectory(
            at: dataDirectoryUrl(), includingPropertiesForKeys: nil
        )

        for filename in fileUrls {
            if !excludedFiles.contains(where: { filename.lastPathComponent.contains($0) }) {
                try fileManager.removeItem(at: filename)
            }
        }
    }

    public static func instance(accountId: String, keyPair: KeyPair? = nil, testNet: Bool = false, walletId: String, minLogLevel: Logger.Level = .error) throws -> Kit {
        let logger = Logger(minLogLevel: minLogLevel)
        let uniqueId = "\(walletId)-\(testNet)"

        let databaseURL = try dataDirectoryUrl().appendingPathComponent(
            "stellar-\(uniqueId).sqlite")

        let dbPool = try DatabasePool(path: databaseURL.path)

        let sdk = sdk(testNet: testNet)

        let api = StellarApi(sdk: sdk, testNet: testNet)

        let accountStorage = try AccountStorage(dbPool: dbPool)
        let accountManager = try AccountManager(
            accountId: accountId, api: api, storage: accountStorage, logger: logger
        )

        let operationStorage = try OperationStorage(dbPool: dbPool)
        let operationManager = OperationManager(
            accountId: accountId, api: api, storage: operationStorage, logger: logger
        )

        var transactionSender: TransactionSender?

        if let keyPair {
            transactionSender = TransactionSender(keyPair: keyPair, api: api, logger: logger)
        }

        let kit = Kit(
            accountId: accountId,
            accountManager: accountManager,
            operationManager: operationManager,
            transactionSender: transactionSender,
            logger: logger
        )

        return kit
    }

    private static func sdk(testNet: Bool) -> StellarSDK {
        testNet ? StellarSDK.testNet() : StellarSDK.publicNet()
    }

    private static func dataDirectoryUrl() throws -> URL {
        let fileManager = FileManager.default

        let url =
            try fileManager
                .url(
                    for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
                    create: true
                )
                .appendingPathComponent("stellar-kit", isDirectory: true)

        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)

        return url
    }
}

public extension Kit {
    enum SyncError: Error {
        case notStarted
    }

    enum SendError: Error {
        case noTransactionSender
        case invalidAsset
    }
}
