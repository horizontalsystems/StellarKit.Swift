import Foundation

public enum Asset: Codable, Hashable {
    case native
    case asset(code: String, issuer: String)

    init(id: String) {
        let components = id.components(separatedBy: ":")

        if components.count == 1 {
            self = .native
        } else {
            self = .asset(code: components[0], issuer: components[1])
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

    public var id: String {
        switch self {
        case .native: return "native"
        case let .asset(code, issuer): return "\(code):\(issuer)"
        }
    }
}
