import Foundation
import stellarsdk

public enum Asset: Codable, Hashable {
    case native
    case asset(code: String, issuer: String)

    public init?(id: String) {
        if id == "native" || id == "XLM" {
            self = .native
            return
        }

        let components: [String]

        if id.contains(":") {
            components = id.components(separatedBy: ":")
        } else {
            components = id.components(separatedBy: "-")
        }

        if components.count != 2 {
            return nil
        }

        let code = components[0].trimmingCharacters(in: .whitespaces)
        let issuer = components[1].trimmingCharacters(in: .whitespaces)

        do {
            _ = try PublicKey(accountId: issuer)
            self = .asset(code: code, issuer: issuer)
        } catch {
            return nil
        }
    }

    public var isNative: Bool {
        switch self {
        case .native: return true
        default: return false
        }
    }

    public var code: String {
        switch self {
        case .native: return "XLM"
        case let .asset(code, _): return code
        }
    }

    public var issuer: String? {
        switch self {
        case .native: return nil
        case let .asset(_, issuer): return issuer
        }
    }

    public var id: String {
        switch self {
        case .native: return "native"
        case let .asset(code, issuer): return "\(code):\(issuer)"
        }
    }
}
