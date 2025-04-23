import Combine
import Foundation
import StellarKit

class OperationViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    @Published var syncState: SyncState
    @Published var operations: [TxOperation] = []

    @Published var operationType: OperationType = .all {
        didSet {
            syncTagQuery()
        }
    }

    @Published var operationAsset: OperationAsset = .all {
        didSet {
            syncTagQuery()
        }
    }

    @Published var operationAccountId: String = "" {
        didSet {
            syncTagQuery()
        }
    }

    init() {
        syncState = Singleton.stellarKit?.syncState ?? .notSynced(error: AppError.noStellarKit)

        syncTagQuery()
    }

    private func syncTagQuery() {
        let tagQuery = TagQuery(
            type: operationType.tagType,
            assetId: operationAsset.tagAssetId,
            accountId: operationAccountId.isEmpty ? nil : operationAccountId
        )

        sync(tagQuery: tagQuery)
        subscribe(tagQuery: tagQuery)
    }

    private func sync(tagQuery: TagQuery) {
        operations = Singleton.stellarKit?.operations(tagQuery: tagQuery) ?? []
    }

    private func subscribe(tagQuery: TagQuery) {
        Singleton.stellarKit?.operationPublisher(tagQuery: tagQuery)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.sync(tagQuery: tagQuery)
            }
            .store(in: &cancellables)
    }

    var operationAssets: [OperationAsset] {
        guard let stellarKit = Singleton.stellarKit else {
            return []
        }

        return [.all] + stellarKit.operationAssets().map { OperationAsset.asset(asset: $0) }
    }
}

extension OperationViewModel {
    enum OperationType: String, CaseIterable {
        case all
        case incoming
        case outgoing

        var tagType: Tag.`Type`? {
            switch self {
            case .all: return nil
            case .incoming: return .incoming
            case .outgoing: return .outgoing
            }
        }
    }

    enum OperationAsset: Hashable {
        case all
        case asset(asset: Asset)

        var title: String {
            switch self {
            case .all: return "All"
            case let .asset(asset): return asset.code
            }
        }

        var tagAssetId: String? {
            switch self {
            case .all: return nil
            case let .asset(asset): return asset.id
            }
        }
    }
}
