//
// The MIT License (MIT)
//
// Copyright (c) 2017 Tommaso Madonia
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
import CFNetwork
import Foundation
// MARK: - SSH Library

/// A library that implements the SSH2 protocol.
public protocol SSHLibrary {

    /// The name of the library.
    static var name: String { get }
    
    /// The version of the library.
    static var version: String { get }

    /// Initialize a new SSH session.
    ///
    /// - Returns: The SSH session.
    static func makeSession() throws -> SSHLibrarySession
    
}

// MARK: - Session

public protocol SSHLibrarySession {
    
    var authenticated: Bool { get }
    var blocking: Bool { get set }
    var banner: String? { get }
    var timeout: Int { get set }
    
    func makeChannel() -> SSHLibraryChannel
    func setBanner(_ banner: String) throws
    func handshake(_ socket: CFSocket) throws
    func fingerprint(_ hashType: FingerprintHashType) -> String?
    func authenticationList(_ username: String) throws -> [String]
    func authenticateByPassword(_ username: String, password: String) throws
    func authenticateByKeyboardInteractive(_ username: String, callback: @escaping ((String) -> String)) throws
    func authenticateByPublicKeyFromFile(_ username: String, password: String, publicKey: String?, privateKey: String) throws
    func authenticateByPublicKeyFromMemory(_ username: String, password: String, publicKey: Data?, privateKey: Data) throws
    func authenticateByCallback(_ username: String, publicKey: Data) throws
    func disconnect() throws
    
}

// MARK: - Channel

public protocol SSHLibraryChannel {
    
    var opened: Bool { get }
    var receivedEOF: Bool { get }
    
    func openChannel() throws
    func closeChannel() throws
    func setEnvironment(_ environment: Environment) throws
    func requestPseudoTerminal(_ terminal: Terminal) throws
    func setPseudoTerminalSize(_ terminal: Terminal) throws
    func exec(_ command: String) throws
    func shell() throws
    func read() throws -> Data
    func readError() throws -> Data
    func write(_ data: Data) -> (error: Error?, bytesSent: Int)
    func exitStatus() -> Int?
    func sendEOF() throws
    
}

// MARK: - SFTP

public protocol SSHLibrarySFTP {
    
}

// MARK: - SCP

public protocol SSHLibrarySCP {
    
}

// MARK: - Fingerprint

public enum FingerprintHashType: CustomStringConvertible {
    
    case md5, sha1
    
    public var description: String {
        switch self {
        case .md5:  return "MD5"
        case .sha1: return "SHA1"
        }
    }
    
}

// MARK: - Authentication

public enum AuthenticationMethod: CustomStringConvertible, Equatable {

    case password, keyboardInteractive, publicKey
    case unknown(String)

    public init(_ rawValue: String) {
        switch rawValue.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
            case "password": self = .password
            case "keyboard-interactive": self = .keyboardInteractive
            case "publickey": self = .publicKey
            default: self = .unknown(rawValue)
        }
    }

    public var description: String {
        switch self {
            case .password: return "Password"
            case .keyboardInteractive: return "Keyboard Interactive"
            case .publicKey: return "Public Key"
            case .unknown(let method): return method
        }
    }

}

public enum AuthenticationChallenge {

    case byPassword(username: String, password: String)
    case byKeyboardInteractive(username: String, callback: ((String) -> String))
    case byPublicKeyFromFile(username: String, password: String, publicKey: String?, privateKey: String)
    case byPublicKeyFromMemory(username: String, password: String, publicKey: Data?, privateKey: Data)
    case byCallback (username: String, publicKey: Data)
    
    var username: String {
        switch self {
        case .byPassword(let username, _), .byKeyboardInteractive(let username, _), .byPublicKeyFromFile(let username, _, _, _), .byPublicKeyFromMemory(let username, _, _, _), .byCallback(username: let username, _):
                return username
        }
    }

    var requiredAuthenticationMethod: AuthenticationMethod {
        switch self {
            case .byPassword: return .password
            case .byKeyboardInteractive: return .keyboardInteractive
            case .byPublicKeyFromFile, .byPublicKeyFromMemory: return .publicKey
            case .byCallback: return .publicKey
        }
    }

}

// MARK: - Environment

public struct Environment {

    public let name: String
    public let variable: String

    public init (name: String, variable: String)
    {
        self.name = name
        self.variable = variable
    }
}

// MARK: - Terminal

public struct Terminal: ExpressibleByStringLiteral, CustomStringConvertible {
    
    public let name: String
    public var width: UInt
    public var height: UInt
    
    public var description: String {
        return "\(self.name) [\(self.width)x\(self.height)]"
    }

    public init(_ name: String, width: UInt = 80, height: UInt = 24) {
        self.name = name
        self.width = width
        self.height = height
    }
    
    public init(unicodeScalarLiteral value: String) {
        self.name = value
        self.width = 80
        self.height = 24
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        self.name = value
        self.width = 80
        self.height = 24
    }
    
    public init(stringLiteral value: StringLiteralType) {
        self.name = value
        self.width = 80
        self.height = 24
    }
    
}
