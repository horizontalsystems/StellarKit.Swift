import Combine
import Foundation
import HsToolKit
import StellarKit
import stellarsdk

enum Singleton {
    static var stellarKit: Kit?
    static var keyPair: KeyPair?
}

enum AppError: Error {
    case noStellarKit
}

class AppViewModel: ObservableObject {
    private let keyWords = "mnemonic_words"
    private let keyAddress = "address"

    @Published var stellarKit: Kit?

    init() {
        if let words = savedWords {
            try? initKit(words: words)
        } else if let address = savedAddress {
            try? initKit(address: address)
        }
    }

    private func initKit(accountId: String, keyPair: KeyPair?) throws {
        let configuration = Configuration.shared

        let stellarKit = try Kit.instance(
            accountId: accountId,
            keyPair: keyPair,
            testNet: configuration.testNet,
            walletId: accountId,
            minLogLevel: configuration.minLogLevel
        )

        stellarKit.sync()

        Singleton.stellarKit = stellarKit
        Singleton.keyPair = keyPair
        self.stellarKit = stellarKit
    }

    private func initKit(words: [String]) throws {
        let keyPair = try! WalletUtils.createKeyPair(mnemonic: words.joined(separator: " "), passphrase: nil, index: 0)
        try initKit(accountId: keyPair.accountId, keyPair: keyPair)
    }

    private func initKit(address: String) throws {
        try initKit(accountId: address, keyPair: nil)
    }

    private var savedWords: [String]? {
        guard let wordsString = UserDefaults.standard.value(forKey: keyWords) as? String else {
            return nil
        }

        return wordsString.split(separator: " ").map(String.init)
    }

    private var savedAddress: String? {
        UserDefaults.standard.value(forKey: keyAddress) as? String
    }

    private func save(words: [String]) {
        UserDefaults.standard.set(words.joined(separator: " "), forKey: keyWords)
        UserDefaults.standard.synchronize()
    }

    private func save(address: String) {
        UserDefaults.standard.set(address, forKey: keyAddress)
        UserDefaults.standard.synchronize()
    }

    private func clearStorage() {
        UserDefaults.standard.removeObject(forKey: keyWords)
        UserDefaults.standard.removeObject(forKey: keyAddress)
        UserDefaults.standard.synchronize()
    }
}

extension AppViewModel {
    func login(words: [String]) throws {
        try Kit.clear(exceptFor: [])

        try initKit(words: words)
        save(words: words)
    }

    func watch(address: String) throws {
        try Kit.clear(exceptFor: [])

        try initKit(address: address)
        save(address: address)
    }

    func logout() {
        clearStorage()

        stellarKit = nil
        Singleton.stellarKit = nil
    }
}

extension AppViewModel {
    enum LoginError: Error {
        case emptyWords
        case seedGenerationFailed
    }
}
