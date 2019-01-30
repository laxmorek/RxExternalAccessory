//
//  RxExternalAccessory.swift
//  RxEAAccessoryManager
//
//  Created by Kamil Harasimowicz on 25/01/2019.
//

import ExternalAccessory
import RxSwift

protocol RxEAAccessoryManagerProtocol {
    
    var accessory: Observable<EAAccessory?> { get }
    var session: Observable<EASession?> { get }
    var connectedAccessories: Observable<[EAAccessory]> { get }
    
    func showBluetoothAccessoryPicker(withNameFilter predicate: NSPredicate?) -> Observable<BluetoothAccessoryPickerResult>
    
    func startCommunicating(withAccessory accessory: EAAccessory, forProtocol protocolString: String) -> Observable<StreamDelegateResult>
    func stopCommunicating()
}

enum BluetoothAccessoryPickerResult {
    case connected
    case alreadyConnected
    case canceled
}

typealias StreamDelegateResult = (aStream: Stream, eventCode: Stream.Event)

enum RxEAAccessoryManagerError: Error {
    case failedToCreateSession(accessory: EAAccessory, protocolString: String)
}

final class RxEAAccessoryManager: NSObject, RxEAAccessoryManagerProtocol {
    
    private let manager: EAAccessoryManager = EAAccessoryManager.shared()
    
    private let connectedAccessoriesSubject: BehaviorSubject<[EAAccessory]>
    let connectedAccessories: Observable<[EAAccessory]>
    
    private let sessionSubject: BehaviorSubject<EASession?>
    let session: Observable<EASession?>
    
    let accessory: Observable<EAAccessory?>
    
    private var streamDelegateResultObserver: AnyObserver<StreamDelegateResult>?
    
    override init() {
        connectedAccessoriesSubject = BehaviorSubject(value: manager.connectedAccessories)
        connectedAccessories = connectedAccessoriesSubject
            .asObservable()
        
        sessionSubject = BehaviorSubject(value: nil)
        session = sessionSubject
            .asObservable()
        
        accessory = sessionSubject
            .map { $0?.accessory }
            .asObservable()
        
        super.init()
        
        observeAccessoryEvents()
    }
    
    deinit {
        stopCommunicating()
        manager.unregisterForLocalNotifications()
    }
}

// MARK: - Communication
extension RxEAAccessoryManager {
    
    func startCommunicating(withAccessory accessory: EAAccessory, forProtocol protocolString: String) -> Observable<StreamDelegateResult> {
        guard let session = EASession(accessory: accessory, forProtocol: protocolString) else {
            return .error(RxEAAccessoryManagerError.failedToCreateSession(accessory: accessory, protocolString: protocolString))
        }
        
        return Observable<StreamDelegateResult>.create { [weak self] observer in
            guard let self = self else { return Disposables.create() }
            
            self.closeSocketIfSessionExsit()
            
            self.streamDelegateResultObserver = observer
            
            self.openSocket(for: session)
            self.sessionSubject.onNext(session)
            
            return Disposables.create {
                self.stopCommunicating()
            }
        }
    }
    
    func stopCommunicating() {
        closeSocketIfSessionExsit()
        sessionSubject.onNext(nil)
    }
    
    private func closeSocketIfSessionExsit() {
        if let hasCurrentSession = try? sessionSubject.value(), let currentSession = hasCurrentSession {
            closeSocket(for: currentSession)
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
                        case EABluetoothAccessoryPickerError.resultCancelled:
                            observer.onNext(.canceled)
                            observer.onCompleted()
                        case EABluetoothAccessoryPickerError.resultNotFound,
                             EABluetoothAccessoryPickerError.resultFailed:
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

// MARK: - Socket managment
extension RxEAAccessoryManager {
    
    private func openSocket(for session: EASession) {
        if let inputStream = session.inputStream {
            inputStream.delegate = self
            inputStream.schedule(in: .current, forMode: .default)
            inputStream.open()
        }
        if let outputStream = session.outputStream {
            outputStream.close()
            outputStream.remove(from: .current, forMode: RunLoop.Mode.default)
            outputStream.delegate = nil
        }
    }
    
    private func closeSocket(for session: EASession) {
        if let inputStream = session.inputStream {
            inputStream.close()
            inputStream.remove(from: .current, forMode: .default)
            inputStream.delegate = nil
        }
        if let outputStream = session.outputStream {
            outputStream.close()
            outputStream.remove(from: .current, forMode: .default)
            outputStream.delegate = nil
        }
    }
}

// MARK: - StreamDelegate
extension RxEAAccessoryManager: StreamDelegate {
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        if let streamDelegateResultObserver = streamDelegateResultObserver {
            streamDelegateResultObserver.onNext((aStream: aStream, eventCode: eventCode))
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
