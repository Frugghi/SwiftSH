//
//  AuthenticationTests.swift
//  SwiftSH Integration Tests
//
//  Created by Tommaso Madonia on 14/08/2018.
//  Copyright © 2018 Tommaso Madonia. All rights reserved.
//

import XCTest
@testable import SwiftSH

class AuthenticationTests: XCTestCase {
    
    private let config = Config.load()
    private var session: SSHSession<Libssh2>!
    
    override func setUp() {
        super.setUp()
        
        self.session = SSHSession(host: self.config.session.host, port: self.config.session.port)
    }
    
    override func tearDown() {
        self.session = nil
        
        super.tearDown()
    }
    
    func testSessionNotAuthenticatedAfterConnection() {
        let expectation = XCTestExpectation(description: "Session not authenticated after connection")
        
        XCTAssertFalse(self.session.authenticated, "Session is already authenticated")

        self.session.connect { _ in
            XCTAssertFalse(self.session.authenticated, "Session is authenticated")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    func testAuthenticationByPassword() {
        let username = self.config.authentication.password.username
        let password = self.config.authentication.password.password
        
        self.authenticate(.byPassword(username: username, password: password))
    }
    
    func testAuthenticationByKeyboardInteractive() {
        let username = self.config.authentication.keyboardInteractive.username
        let password = self.config.authentication.keyboardInteractive.password
        
        self.authenticate(.byKeyboardInteractive(username: username) { _ in password })
    }
    
    func testAuthenticationByPublicKeyFromMemory() {
        let username = self.config.authentication.publicKey.username
        let password = self.config.authentication.publicKey.password
        let publicKey = NSDataAsset(name: self.config.authentication.publicKey.publicKey, bundle: Config.bundle)!.data
        let privateKey = NSDataAsset(name: self.config.authentication.publicKey.privateKey, bundle: Config.bundle)!.data
        
        self.authenticate(.byPublicKeyFromMemory(username: username, password: password, publicKey: publicKey, privateKey: privateKey))
    }
    
    func testAuthenticationByPublicKeyFromMemoryWithNilPublicKey() {
        let username = self.config.authentication.publicKey.username
        let password = self.config.authentication.publicKey.password
        let privateKey = NSDataAsset(name: self.config.authentication.publicKey.privateKey, bundle: Config.bundle)!.data
        
        self.authenticate(.byPublicKeyFromMemory(username: username, password: password, publicKey: nil, privateKey: privateKey))
    }
    
    func testAuthenticationByPublicKeyFromFile() {
        let username = self.config.authentication.publicKey.username
        let password = self.config.authentication.publicKey.password
        var publicKey = ""
        var privateKey = ""
        
        XCTAssertNoThrow(publicKey = try self.writeTempFile(NSDataAsset(name: self.config.authentication.publicKey.publicKey, bundle: Config.bundle)!.data)!.path)
        XCTAssertNoThrow(privateKey = try self.writeTempFile(NSDataAsset(name: self.config.authentication.publicKey.privateKey, bundle: Config.bundle)!.data)!.path)
                
        defer {
            _ = URL(string: publicKey)?.withUnsafeFileSystemRepresentation { unlink($0) }
            _ = URL(string: privateKey)?.withUnsafeFileSystemRepresentation { unlink($0) }
        }
        
        self.authenticate(.byPublicKeyFromFile(username: username, password: password, publicKey: publicKey, privateKey: privateKey))
    }
    
    func testAuthenticationByPublicKeyFromFileWithNilPublicKey() {
        let username = self.config.authentication.publicKey.username
        let password = self.config.authentication.publicKey.password
        var privateKey = ""
        
        XCTAssertNoThrow(privateKey = try self.writeTempFile(NSDataAsset(name: self.config.authentication.publicKey.privateKey, bundle: Config.bundle)!.data)!.path)
        
        defer {
            _ = URL(string: privateKey)?.withUnsafeFileSystemRepresentation { unlink($0) }
        }
        
        self.authenticate(.byPublicKeyFromFile(username: username, password: password, publicKey: nil, privateKey: privateKey))
    }
    
    private func writeTempFile(_ data: Data) throws -> URL? {
        let filePath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        
        try data.write(to: filePath)
        
        return filePath
    }
    
    private func authenticate(_ authenticationChallenge: AuthenticationChallenge) {
        let expectation = XCTestExpectation(description: "Authenticate using \(authenticationChallenge.requiredAuthenticationMethod) authentication")

        XCTAssertFalse(self.session.authenticated, "Session is already authenticated")
        
        self.session
            .connect()
            .authenticate(authenticationChallenge) { [unowned self] (error) in
                XCTAssertNil(error, "\(authenticationChallenge.requiredAuthenticationMethod) authentication failed")
                XCTAssertTrue(self.session.authenticated, "Session is not authenticated")
                
                expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
}
