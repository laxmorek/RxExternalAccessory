//
//  RxExternalAccessory.swift
//  RxEAAccessoryManager
//
//  Created by Kamil Harasimowicz on 25/01/2019.
//

import ExternalAccessory
import RxSwift

protocol RxEAAccessoryManagerProtocol {
    
    var connectedAccessories: Observable<[EAAccessory]> { get }
    
    func showBluetoothAccessoryPicker(withNameFilter predicate: NSPredicate?) -> Observable<BluetoothAccessoryPickerResult>
    func startCommunication(withAccessory accessory: EAAccessory, forProtocol protocolString: String) -> Observable<Data>
}

enum BluetoothAccessoryPickerResult {
    case connected
    case alreadyConnected
}

final class RxEAAccessoryManager: NSObject {
    
    private let manager: EAAccessoryManager = EAAccessoryManager.shared()
    
    private var currentAccessory: EAAccessory? = nil
    private var currentSession: EASession? = nil
    
    private let connectedAccessoriesSubject: BehaviorSubject<[EAAccessory]>
    let connectedAccessories: Observable<[EAAccessory]>
    
    private var inputDataSubject = PublishSubject<Data>()
    
    override init() {
        connectedAccessoriesSubject = BehaviorSubject(value: manager.connectedAccessories)
        connectedAccessories = connectedAccessoriesSubject.asObservable()
        
        super.init()
        
        observeAccessoryEvents()
    }
    
    deinit {
        manager.unregisterForLocalNotifications()
    }
}

// MARK: - Communication
extension RxEAAccessoryManager: StreamDelegate {
    
    enum Error: Swift.Error {
        case sessionCreateFailed
    }
    
    func startCommunication(withAccessory accessory: EAAccessory, forProtocol protocolString: String) -> Observable<Data> {
        guard let session = EASession(accessory: accessory, forProtocol: protocolString) else {
            return .error(Error.sessionCreateFailed)
        }
        
        closeSocket()
        
        currentAccessory = accessory
        currentSession = session
        
        openSocket()
        
        return inputDataSubject.asObservable()
    }
    
    private func openSocket() {
        if let inputStream = currentSession?.inputStream {
            inputStream.delegate = self
            inputStream.schedule(in: .current, forMode: RunLoop.Mode.default)
            inputStream.open()
        }
        if let outputStream = currentSession?.outputStream {
            outputStream.delegate = self
            outputStream.schedule(in: .current, forMode: RunLoop.Mode.default)
            outputStream.open()
        }
    }
    
    private func closeSocket() {
        if let inputStream = currentSession?.inputStream {
            inputStream.close()
            inputStream.remove(from: .current, forMode: RunLoop.Mode.default)
            inputStream.delegate = nil
        }
        if let outputStream = currentSession?.outputStream {
            outputStream.close()
            outputStream.remove(from: .current, forMode: RunLoop.Mode.default)
            outputStream.delegate = nil
        }
        
        currentSession = nil
        currentAccessory = nil
    }
    
    private func readData() {
        let readBuffer = NSMutableData()
        
        if let inputStream = currentSession?.inputStream {
            let bufferSize = 1024
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            while inputStream.hasBytesAvailable {
                let read = inputStream.read(buffer, maxLength: bufferSize)
                if read == 0 {
                    break //EOS
                }
                readBuffer.append(buffer, length: read)
            }
            buffer.deallocate()
            
            inputDataSubject.on(readBuffer.mutableBytes)
            
            let newline = Data(bytes: [0x0d, 0x0a])
            let responseEndRange = readBuffer.range(of: newline, options: [], in: NSRange(location: 0, length: readBuffer.length))
            readBuffer.replaceBytes(in: NSRange(location: 0, length: responseEndRange.location + responseEndRange.length), withBytes: nil, length: 0)
        }
    }
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
            readData()
        default:
            break
        }
    }
}

// MARK: - BluetoothAccessoryPicker
extension RxEAAccessoryManager {
    
    func showBluetoothAccessoryPicker(withNameFilter predicate: NSPredicate?) -> Observable<BluetoothAccessoryPickerResult> {
        return Observable.create { [manager] observer in
            manager.showBluetoothAccessoryPicker(
                withNameFilter: predicate,
                completion: { error in
                    if let error = error {
                        switch error {
                        case EABluetoothAccessoryPickerError.alreadyConnected:
                            observer.onNext(.alreadyConnected)
                            observer.onCompleted()
                        case EABluetoothAccessoryPickerError.resultNotFound,
                             EABluetoothAccessoryPickerError.resultFailed,
                             EABluetoothAccessoryPickerError.resultCancelled:
                            observer.onError(error)
                        default:
                            observer.onError(error)
                        }
                    } else {
                        observer.onNext(.connected)
                        observer.onCompleted()
                    }
                }
            )
            
            return Disposables.create()
        }
    }
}

// MARK: - Notifications
extension RxEAAccessoryManager {
    
    private func observeAccessoryEvents() {
        NotificationCenter.default.addObserver(self, selector: #selector(onAccessoryConnection(_:)), name: .EAAccessoryDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onAccessoryDisconnection(_:)), name: .EAAccessoryDidDisconnect, object: nil)
        
        manager.registerForLocalNotifications()
    }
    
    @objc private func onAccessoryConnection(_ notification: Notification) {
        connectedAccessoriesSubject.onNext(manager.connectedAccessories)
    }
    
    @objc private func onAccessoryDisconnection(_ notification: Notification) {
        connectedAccessoriesSubject.onNext(manager.connectedAccessories)
    }
}
