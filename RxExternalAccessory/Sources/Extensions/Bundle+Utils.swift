//
//  Bundle+Utils.swift
//  RxExternalAccessory
//
//  Created by Kamil Harasimowicz on 25/01/2019.
//

import Foundation

// MARK: - Utils
extension Bundle {
    
    /// returns value for key "UISupportedExternalAccessoryProtocols"
    var supportedAccessoryProtocols: [String] {
        return object(forInfoDictionaryKey: "UISupportedExternalAccessoryProtocols") as? [String] ?? []
    }
}
