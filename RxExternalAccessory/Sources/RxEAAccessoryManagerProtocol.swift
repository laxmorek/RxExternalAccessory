//
//  RxEAAccessoryManagerProtocol.swift
//  RxExternalAccessory
//
//  Created by Kamil Harasimowicz on 30/01/2019.
//

import ExternalAccessory
import RxSwift

protocol RxEAAccessoryManagerProtocol {
    
    var accessory: Observable<EAAccessory?> { get }
    var session: Observable<EASession?> { get }
    var connectedAccessories: Observable<[EAAccessory]> { get }
    
    func showBluetoothAccessoryPicker(withNameFilter predicate: NSPredicate?) -> Observable<BluetoothAccessoryPickerResult>
    
    func startCommunicating(withAccessory accessory: EAAccessory, forProtocol protocolString: String) -> Observable<StreamResult>
    func stopCommunicating()
}

typealias StreamResult = (aStream: Stream, eventCode: Stream.Event)

enum BluetoothAccessoryPickerResult {
    case connected
    case alreadyConnected
    case canceled
}

enum SessionError: Error {
    case failedToCreateSession(accessory: EAAccessory, protocolString: String)
}
