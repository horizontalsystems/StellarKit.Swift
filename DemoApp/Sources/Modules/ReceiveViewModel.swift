import Combine

class ReceiveViewModel: ObservableObject {
    var address: String {
        Singleton.stellarKit?.receiveAddress ?? ""
    }
}
