# StellarKit.Swift

`StellarKit.Swift` is a native (Swift) toolkit for Stellar blockchain. It's implemented and used by [Unstoppable Wallet](https://github.com/horizontalsystems/unstoppable-wallet-ios), a multi-currency crypto wallet.

## Installation

### Swift Package Manager

[Swift Package Manager](https://www.swift.org/package-manager) is a dependency manager for Swift projects. You can install it with the following command:

```swift
dependencies: [
    .package(url: "https://github.com/horizontalsystems/StellarKit.Swift.git", .upToNextMajor(from: "1.0.8"))
]
```

## Prerequisites

* Xcode 15.0+
* Swift 5.5+
* iOS 16+

## Quick Start

### 1. Create and Prepare StellarKit 

```swift
let stellarKit = try Kit.instance(
    accountId: "STELLAR_ACCOUNT_ID",
    testNet: false,
    walletId: "WALLET_UNIQUE_ID", // any unique id, used to distinguish multiple StellarKit instances
    minLogLevel: .error
)

stellarKit.sync()
```

Any time later kit can be synced manually by calling `sync()` method. 

### 2. Get Data from StellarKit

#### 2.1. Sync States

```swift
// Get account sync state
stellarKit.syncState
stellarKit.syncStatePublisher

// Get operation sync state
stellarKit.operationSyncState
stellarKit.operationSyncStatePublisher
```

Sync state is enum with the following cases:

```swift
enum SyncState {
    case synced
    case syncing
    case notSynced(error: Error)
}
```

#### 2.2. Account

Account is `optional`. If account has `synced` sync state, but is `nil` - this means that account does not yet exist in blockchain.

```swift
// Get currently synced account
stellarKit.account
stellarKit.accountPublisher
```

Account and Asset structures:

```swift
struct Account {
    let subentryCount: UInt
    let assetBalanceMap: [Asset: AssetBalance]
}

enum Asset {
    case native
    case asset(code: String, issuer: String)
}

struct AssetBalance {
    let asset: Asset
    let balance: Decimal
    let limit: Decimal?
}
```

#### 2.3. Receive Address

```swift
// Get receive address
stellarKit.receiveAddress
```

### 3. Listening to Operation Stream

Starts listening to operation stream and handle automatic syncing of kit when any new operation is received

```swift
stellarKit.startListener()
stellarKit.stopListener()
```

### 4. Send Transaction

In order to send transactions you need a valid [KeyPair](https://github.com/Soneso/stellar-ios-mac-sdk?tab=readme-ov-file#1-create-a-stellar-key-pair) 

#### 4.1. Prepare Asset

```swift
let nativeAsset = Asset.native
let asset = Asset.asset(code: "CODE", issuer: "ISSUER")
```

#### 4.2. Supported Operations

```swift
let paymentOperation = try stellarKit.paymentOperation(
    asset: asset, // or nativeAsset
    destinationAccountId: "destination_account_id",
    amount: 1.23
)
```

```swift
let createAccountOperation = try stellarKit.createAccountOperation(
    destinationAccountId: "destination_account_id",
    amount: 1.23
)
```

```swift
let changeTrustOperation = try stellarKit.changeTrustOperation(
    asset: asset,
    limit: nil // nil for unlimited or any other amount
)
```

#### 4.3. Send Transaction

```swift
let memo = "memo_here"

let txId = try await StellarKit.Kit.send(
    operations: [paymentOperation],
    memo: memo,
    keyPair: keyPair,
    testNet: false
)
```

## Example Project

All features of the library are used in example project located in `Demo App` folder. It can be referred as a starting point for usage of the library.

## License

The `StellarKit.Swift` toolkit is open source and available under the terms of the [MIT License](https://github.com/horizontalsystems/StellarKit.Swift/blob/master/LICENSE).
