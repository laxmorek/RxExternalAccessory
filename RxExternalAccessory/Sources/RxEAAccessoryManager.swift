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
}

enum BluetoothAccessoryPickerResult {
    case connected
    case alreadyConnected
}

final class RxEAAccessoryManager {
    
    private let manager: EAAccessoryManager = EAAccessoryManager.shared()
    
    private let connectedAccessoriesSubject: BehaviorSubject<[EAAccessory]>
    let connectedAccessories: Observable<[EAAccessory]>
    
    init() {
        connectedAccessoriesSubject = BehaviorSubject(value: manager.connectedAccessories)
        connectedAccessories = connectedAccessoriesSubject.asObservable()
        
        observeAccessoryEvents()
    }
    
    deinit {
        manager.unregisterForLocalNotifications()
    }
    
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
