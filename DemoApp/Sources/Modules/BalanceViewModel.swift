import Combine
import Foundation
import StellarKit

class BalanceViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    @Published var syncState: SyncState
    @Published var assetBalances: [Asset: Decimal] = [:]

    @Published var transactionSyncState: SyncState

    init() {
        syncState = Singleton.stellarKit?.syncState ?? .notSynced(error: AppError.noStellarKit)
        assetBalances = Singleton.stellarKit?.assetBalances ?? [:]

        transactionSyncState =
            Singleton.stellarKit?.operationSyncState ?? .notSynced(error: AppError.noStellarKit)

        Singleton.stellarKit?.syncStatePublisher.receive(on: DispatchQueue.main).sink {
            [weak self] in self?.syncState = $0
        }.store(in: &cancellables)

        Singleton.stellarKit?.assetBalancePublisher.receive(on: DispatchQueue.main).sink { [weak self] in
            self?.assetBalances = $0
        }.store(in: &cancellables)

        Singleton.stellarKit?.addedAssetPublisher.receive(on: DispatchQueue.main).sink { [weak self] in
            print("Added Assets: \($0.map { $0.code })")
        }.store(in: &cancellables)

        Singleton.stellarKit?.operationSyncStatePublisher.receive(on: DispatchQueue.main).sink {
            [weak self] in self?.transactionSyncState = $0
        }.store(in: &cancellables)
    }

    var address: String {
        Singleton.stellarKit?.receiveAddress ?? ""
    }

    func refresh() {
        Singleton.stellarKit?.sync()
    }
}
