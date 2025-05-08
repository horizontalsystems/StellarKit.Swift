import Foundation
import stellarsdk

protocol IApi {
    func getAccountDetails(accountId: String) async throws -> Account?
    func getOperations(accountId: String, from cursor: String?, asc: Bool, limit: Int) async throws -> [TxOperation]
    func sendTransaction(keyPair: KeyPair, operations: [stellarsdk.Operation], memo: Memo?) async throws -> String
}
