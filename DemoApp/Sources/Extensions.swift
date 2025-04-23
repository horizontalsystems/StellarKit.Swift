extension String: Identifiable {
    public typealias ID = Int
    public var id: Int {
        hash
    }
}
