
//
//  Config.swift
//  SwiftSH Integration Tests
//
//  Created by Tommaso Madonia on 14/08/2018.
//  Copyright © 2018 Tommaso Madonia. All rights reserved.
//

import Foundation
import UIKit

struct Config: Decodable {
    
    static let bundle = Bundle(identifier: "com.tommasomadonia.SwiftSH-Integration-Tests")!
    
    static func load(_ configName: String = "config.docker") -> Config {
        let asset = NSDataAsset(name: configName, bundle: Config.bundle)!
        let decoder = JSONDecoder()
        return try! decoder.decode(Config.self, from: asset.data)
    }
    
    struct Session: Decodable {
        var host: String
        var port: UInt16
        var banner: String
    }
    
    struct Authentication: Decodable {
        
        struct Password: Decodable {
            var username: String
            var password: String
        }
        
        struct KeyboardInteractive: Decodable {
            var username: String
            var password: String
        }
        
        struct PublicKey: Decodable {
            var username: String
            var password: String
            var publicKey: String
            var privateKey: String
        }
        
        var password: Password
        var keyboardInteractive: KeyboardInteractive
        var publicKey: PublicKey
        
    }
    
    var session: Session
    var authentication: Authentication
    
}
