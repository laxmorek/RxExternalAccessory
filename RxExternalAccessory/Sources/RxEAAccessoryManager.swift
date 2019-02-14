//
//  RxExternalAccessory.swift
//  RxEAAccessoryManager
//
//  Created by Kamil Harasimowicz on 25/01/2019.
//

import ExternalAccessory
import RxSwift

/// Rx wrapper around ExternalAccessory framework
public final class RxEAAccessoryManager: NSObject {
    
    public typealias StreamResult = (aStream: Stream, eventCode: Stream.Event)
    
    /// access to wrapped `EAAccessoryManager`
    public let manager: EAAccessoryManager
    
    /// connected accessories
    public let connectedAccessories: Observable<[EAAccessory]>
    private let connectedAccessoriesSubject: BehaviorSubject<[EAAccessory]>
    
    /// current session
    public let session: Observable<EASession?>
    private let sessionSubject: BehaviorSubject<EASession?>
    
    /// `StreamDelegate`'s wrapper
    public let streamResult: Observable<StreamResult>
    private var streamResultSubject: PublishSubject<StreamResult>
    
    /// Init
    ///
    /// - Parameter manager: EAAccessoryManager
    public init(manager: EAAccessoryManager = EAAccessoryManager.shared()) {
        self.manager = manager
        
        connectedAccessoriesSubject = BehaviorSubject(value: manager.connectedAccessories)
        connectedAccessories = connectedAccessoriesSubject
            .asObservable()
        
        sessionSubject = BehaviorSubject(value: nil)
        session = sessionSubject
            .asObservable()
        
        streamResultSubject = PublishSubject()
        streamResult = streamResultSubject
            .asObservable()
        
        super.init()
        
        observeAccessoryEvents()
    }
    
    deinit {
        stopCommunicating()
        manager.unregisterForLocalNotifications()
    }
}

// MARK: - Start Communicating
extension RxEAAccessoryManager {
    
    /// Interates over connected accessories and tries to create EASession.
    ///
    /// - Parameter protocols: protocols
    /// - Returns: true - session opened, false - otherwise
    public func tryConnectingAndStartCommunicating(forProtocols protocols: Set<String>) -> Bool {
        // stop current working session
        stopCommunicating()
        
        // for every connected accessory
        for accessory in manager.connectedAccessories {
            // try to start communication
            return tryConnectingAndStartCommunicating(to: accessory, forProtocols: protocols)
        }
        
        // failed to created session
        return false
    }
    
    /// Tries to create EASession for given accessory
    ///
    /// - Parameters:
    ///   - accessory: accessory
    ///   - protocols: protocols
    /// - Returns: true - session opened, false - otherwise
    public func tryConnectingAndStartCommunicating(to accessory: EAAccessory, forProtocols protocols: Set<String>) -> Bool {
        // stop current working session
        stopCommunicating()
        
        // for every protocol anavaible for accessory
        for accessoryProtocol in accessory.protocolStrings {
            // check if there is a protocol on the wanted one
            guard protocols.contains(accessoryProtocol) else { continue }
            
            // try to create session for match (accessory - protocol)
            if let session = EASession(accessory: accessory, forProtocol: accessoryProtocol) {
                // open sockets (input/output streams)
                openSockets(for: session)
                
                return true
            }
        }
        
        return false
    }
    
    private func openSockets(for session: EASession) {
        // close previous connection (if exist any)
        self.closeSocketIfExsit()
        
        // open new connetion
        self.openSocket(for: session)
        self.sessionSubject.onNext(session)
    }
}

// MARK: - Stop Communicating
extension RxEAAccessoryManager {
    
    /// close current opened EASession
    public func stopCommunicating() {
        // close current connection
        closeSocketIfExsit()
        
        // clean up
        sessionSubject.onNext(nil)
    }
    
    private func closeSocketIfExsit() {
        if let hasCurrentSession = try? sessionSubject.value(), let currentSession = hasCurrentSession {
            closeSocket(for: currentSession)
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
            outputStream.delegate = self
            outputStream.schedule(in: .current, forMode: .default)
            outputStream.open()
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
    
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        streamResultSubject.onNext((aStream: aStream, eventCode: eventCode))
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
        if (notification.userInfo?[EAAccessorySelectedKey] as? EAAccessory) != nil {
            // better support will be added later
        }
        if (notification.userInfo?[EAAccessoryKey] as? EAAccessory) != nil {
            // better support will be added later
        }
        
        // update current connected accessories
        connectedAccessoriesSubject.onNext(manager.connectedAccessories)
    }
    
    @objc private func onAccessoryDisconnection(_ notification: Notification) {
        // catch disconnected accessory and clean-up session if any related
        if let accessory = notification.userInfo?[EAAccessoryKey] as? EAAccessory {
            // check is session exist and its related to disconnected accessory
            if
                let hasCurrentSession = try? sessionSubject.value(),
                let currentSession = hasCurrentSession,
                currentSession.accessory?.connectionID == accessory.connectionID
            {
                // stop session
                stopCommunicating()
            }
        }
        
        // update current connected accessories
        connectedAccessoriesSubject.onNext(manager.connectedAccessories)
    }
}
