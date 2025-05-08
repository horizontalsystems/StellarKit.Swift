import Combine
import Foundation
import StellarKit

class BalanceViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    @Published var syncState: SyncState
    @Published var account: Account?

    @Published var transactionSyncState: SyncState

    init() {
        syncState = Singleton.stellarKit?.syncState ?? .notSynced(error: AppError.noStellarKit)
        account = Singleton.stellarKit?.account

        transactionSyncState =
            Singleton.stellarKit?.operationSyncState ?? .notSynced(error: AppError.noStellarKit)

        Singleton.stellarKit?.syncStatePublisher.receive(on: DispatchQueue.main).sink {
            [weak self] in self?.syncState = $0
        }.store(in: &cancellables)

        Singleton.stellarKit?.accountPublisher.receive(on: DispatchQueue.main).sink { [weak self] in
            self?.account = $0
        }.store(in: &cancellables)

        Singleton.stellarKit?.addedAssetPublisher.receive(on: DispatchQueue.main).sink {
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
