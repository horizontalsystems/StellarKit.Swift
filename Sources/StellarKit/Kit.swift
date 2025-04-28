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
    private let transactionSender: TransactionSender
    private let logger: Logger?

    private var cancellables = Set<AnyCancellable>()
    private var tasks = Set<AnyTask>()

    init(accountId: String, accountManager: AccountManager, operationManager: OperationManager, transactionSender: TransactionSender, logger: Logger?) {
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

    var assetBalances: [Asset: Decimal] {
        accountManager.assetBalances
    }

    var assetBalancePublisher: AnyPublisher<[Asset: Decimal], Never> {
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

    func baseFee() async throws -> Decimal {
        0.0001
    }

    func paymentOperations(asset: Asset, destinationAccountId: String, amount: Decimal) throws -> [stellarsdk.Operation] {
        try transactionSender.paymentOperations(asset: asset, destinationAccountId: destinationAccountId, amount: amount)
    }

    func trustlineOperations(asset: Asset, limit: Decimal?) throws -> [stellarsdk.Operation] {
        try transactionSender.trustlineOperations(asset: asset, limit: limit)
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

    public static func instance(accountId: String, testNet: Bool = false, walletId: String, minLogLevel: Logger.Level = .error) throws -> Kit {
        let logger = Logger(minLogLevel: minLogLevel)
        let uniqueId = "\(walletId)-\(testNet)"

        let databaseURL = try dataDirectoryUrl().appendingPathComponent(
            "stellar-\(uniqueId).sqlite")

        let dbPool = try DatabasePool(path: databaseURL.path)

        let api = api(testNet: testNet)

        let accountStorage = try AccountStorage(dbPool: dbPool)
        let accountManager = try AccountManager(
            accountId: accountId, api: api, storage: accountStorage, logger: logger
        )

        let operationStorage = try OperationStorage(dbPool: dbPool)
        let operationManager = OperationManager(
            accountId: accountId, api: api, storage: operationStorage, logger: logger
        )

        let transactionSender = TransactionSender(accountId: accountId)

        let kit = Kit(
            accountId: accountId,
            accountManager: accountManager,
            operationManager: operationManager,
            transactionSender: transactionSender,
            logger: logger
        )

        return kit
    }

    public static func send(operations: [stellarsdk.Operation], memo: Memo = Memo.none, keyPair: KeyPair, testNet: Bool = false) async throws -> String {
        let api = api(testNet: testNet)
        return try await api.sendTransaction(keyPair: keyPair, operations: operations, memo: memo)
    }

    private static func api(testNet: Bool) -> StellarApi {
        let sdk = testNet ? StellarSDK.testNet() : StellarSDK.publicNet()
        return StellarApi(sdk: sdk, testNet: testNet)
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
