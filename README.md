# RxExternalAccessory
![Swift](https://img.shields.io/badge/Swift-4.2-orange.svg)
[![Version](https://img.shields.io/cocoapods/v/RxExternalAccessory.svg?style=flat)](http://cocoapods.org/pods/RxExternalAccessory)
[![License](https://img.shields.io/cocoapods/l/RxExternalAccessory.svg?style=flat)](http://cocoapods.org/pods/RxExternalAccessory)
[![Platform](https://img.shields.io/cocoapods/p/RxExternalAccessory.svg?style=flat)](http://cocoapods.org/pods/RxExternalAccessory)

RxSwift wrapper around ExternalAccessory framework

## Instalation

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

To integrate RxExternalAccessory into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '10.0'
use_frameworks!

pod 'RxExternalAccessory'
```

Then, run the following command:

```bash
$ pod install
```

## Usage

Create `RxEAAccessoryManager` instance:

```swift
let rx_manager = RxEAAccessoryManager()
```

Available actions:

```swift
// tries to open session with first match from available accessories for given `supportedProtocols`
rx_manager.tryConnectingAndStartCommunicating(forProtocols: supportedProtocols)

// tries to open session for given `EAAccessory`
rx_manager.tryConnectingAndStartCommunicating(to: accessory, forProtocols: supportedProtocols)

// stops any working sessions
rx_manager.stopCommunicating()
```

You can observe:

```swift
// available accessories - Observable<[EAAccessory]>
rx_manager.connectedAccessories
    .subscribe(onNext: { accessories in
        // DO SOMETHING
    })
    .disposed(by: disposeBag)

// current opened session (nil if any session on) - Observable<EASession?>
rx_manager.session
    .subscribe(onNext: { session in
        // DO SOMETHING
    })
    .disposed(by: disposeBag)

// calls from `StreamDelegate` - Observable<StreamResult> where StreamResult = (aStream: Stream, eventCode: Stream.Event)
rx_manager.streamResult
    .subscribe(onNext: { stream, eventCode in
        switch (stream, eventCode) {
        case (let inputStream as InputStream, .hasBytesAvailable):
            // DO SOMETHING
            break
        default:
            break
        }
    })
    .disposed(by: disposeBag)
```

## Contributing

Bug reports and pull requests are welcome.

## License

RxExternalAccessory is released under the MIT license. See LICENSE for details.
