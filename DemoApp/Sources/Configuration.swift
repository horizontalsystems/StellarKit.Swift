import HsToolKit

class Configuration {
    static let shared = Configuration()

    let testNet: Bool = false
    let minLogLevel: Logger.Level = .verbose

    let defaultsWords = ""
    let defaultPassphrase = ""

    let defaultsWatchAddress = ""
    let defaultSendAddress = ""
}
